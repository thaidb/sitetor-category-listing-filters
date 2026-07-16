import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

// Store dùng chung giữa filter group-tag (connector after-breadcrumbs) và
// khu kết quả tuỳ biến (connector discovery-list-container-top) trên trang
// category type Mapping. Lọc bằng giao (AND) tag Discourse:
//   GET /c/<slug>/<id>/l/latest.json?tags[]=A&tags[]=B&match_all_tags=true&page=n
// → topic_list.topics (mỗi topic có mảng tags), more_topics_url báo còn trang.

const VIEW_KEY = "sitetor-mapping-view-mode";
const VIEW_MODES = ["table", "grid", "native"];

// 5 nhóm tag — key tiếng Anh, vocab (giá trị tag tiếng Việt) lấy từ settings
// mapping_group_<key>. Thứ tự này cũng là thứ tự cột trong bảng kết quả.
export const GROUP_KEYS = [
  "purpose",
  "industry",
  "position",
  "compass",
  "corner",
];

// tag "chốt" cascade: menu Ngành nghề chỉ hiện khi Nhu cầu chọn Kinh-doanh
export const BUSINESS_PURPOSE_TAG = "Kinh-doanh";

// vocab một nhóm từ settings (list type → chuỗi "a|b|c")
export function groupVocab(key) {
  const raw = settings[`mapping_group_${key}`] || "";
  return raw
    .split("|")
    .map((v) => v.trim())
    .filter(Boolean);
}

// Map lowercase → dạng gốc, để giao topic.tags với vocab không phân biệt hoa
// thường (Discourse có thể lưu tag lowercase tuỳ cấu hình force_lowercase_tags)
export function groupVocabMap(key) {
  return new Map(groupVocab(key).map((v) => [v.toLowerCase(), v]));
}

function readViewMode() {
  try {
    const v = localStorage.getItem(VIEW_KEY);
    return VIEW_MODES.includes(v) ? v : "table";
  } catch {
    return "table";
  }
}

class MappingStore {
  @tracked categoryId = null;
  categoryUrl = null; // "/c/mapping/can-thue-nha-dat/3344" (category.url của core)

  // lựa chọn tạm theo nhóm — chỉ áp vào appliedTags khi bấm Lọc
  @tracked selectedPurpose = [];
  @tracked selectedIndustry = [];
  @tracked selectedPosition = [];
  @tracked selectedCompass = [];
  @tracked selectedCorner = [];

  // hợp tag đã áp dụng (union 5 nhóm) — giữ nguyên khi chuyển trang
  appliedTags = [];

  // kết quả từ topic_list
  @tracked topics = [];
  @tracked page = 0; // 0-based theo query param page của Discourse
  @tracked hasMore = false; // topic_list.more_topics_url có mặt
  @tracked loading = false;
  @tracked loaded = false;

  @tracked viewMode = readViewMode();
  @tracked groupBy = "none"; // none | purpose | industry | position | compass | corner

  resultsActive = false;
  #fetchSeq = 0;

  selectionField(key) {
    return `selected${key.charAt(0).toUpperCase()}${key.slice(1)}`;
  }

  selectionFor(key) {
    return this[this.selectionField(key)];
  }

  // cascade: Nhu cầu có Kinh-doanh → mở menu Ngành nghề
  get purposeIncludesBusiness() {
    return this.selectedPurpose.some(
      (t) => t.toLowerCase() === BUSINESS_PURPOSE_TAG.toLowerCase()
    );
  }

  // hợp tất cả tag đang chọn của 5 nhóm → tags[] (AND intersection phía server)
  get selectedTags() {
    return [
      ...this.selectedPurpose,
      ...this.selectedIndustry,
      ...this.selectedPosition,
      ...this.selectedCompass,
      ...this.selectedCorner,
    ];
  }

  get currentPage() {
    return this.page + 1; // hiển thị 1-based
  }

  get hasPrev() {
    return this.page > 0;
  }

  get hasNext() {
    return this.hasMore;
  }

  setCategory(category) {
    if (!category) {
      return;
    }
    this.categoryId = category.id;
    // category.url của core đã gồm slug path đầy đủ (kể cả parent) + id
    this.categoryUrl = category.url || `/c/${category.slug}/${category.id}`;
  }

  setSelection(key, values) {
    this[this.selectionField(key)] = values;
    // cascade: bỏ Kinh-doanh khỏi Nhu cầu → xoá lựa chọn Ngành nghề (menu ẩn,
    // không để tag ngành "kẹt" lại trong query)
    if (key === "purpose" && !this.purposeIncludesBusiness) {
      this.selectedIndustry = [];
    }
  }

  async fetchResults() {
    if (!this.categoryUrl) {
      return;
    }
    const seq = ++this.#fetchSeq;
    this.loading = true;
    const params = new URLSearchParams();
    for (const tag of this.appliedTags) {
      params.append("tags[]", tag);
    }
    if (this.appliedTags.length) {
      params.set("match_all_tags", "true");
    }
    if (this.page > 0) {
      params.set("page", String(this.page));
    }
    const qs = params.toString();
    try {
      const r = await ajax(
        `${this.categoryUrl}/l/latest.json${qs ? `?${qs}` : ""}`
      );
      if (seq !== this.#fetchSeq) {
        return; // đã có request mới hơn
      }
      const list = r?.topic_list || {};
      this.topics = list.topics || [];
      this.hasMore = !!list.more_topics_url;
      this.loaded = true;
    } catch {
      if (seq === this.#fetchSeq) {
        this.topics = [];
        this.hasMore = false;
        this.loaded = true;
      }
    } finally {
      if (seq === this.#fetchSeq) {
        this.loading = false;
      }
    }
  }

  apply() {
    this.appliedTags = this.selectedTags;
    this.page = 0;
    // đang xem danh sách gốc mà bấm Lọc → chuyển sang bảng để thấy kết quả
    if (this.viewMode === "native") {
      this.setViewMode("table");
    }
    this.fetchResults();
  }

  reset() {
    this.selectedPurpose = [];
    this.selectedIndustry = [];
    this.selectedPosition = [];
    this.selectedCompass = [];
    this.selectedCorner = [];
    this.appliedTags = [];
    this.page = 0;
    this.fetchResults();
  }

  prevPage() {
    if (this.hasPrev) {
      this.page -= 1;
      this.fetchResults();
    }
  }

  nextPage() {
    if (this.hasNext) {
      this.page += 1;
      this.fetchResults();
    }
  }

  setViewMode(mode) {
    if (!VIEW_MODES.includes(mode)) {
      return;
    }
    this.viewMode = mode;
    try {
      localStorage.setItem(VIEW_KEY, mode);
    } catch {
      // localStorage không khả dụng — bỏ qua, chỉ mất persist
    }
    this.syncBodyClass();
  }

  setGroupBy(key) {
    this.groupBy = key === "none" || GROUP_KEYS.includes(key) ? key : "none";
  }

  // khu kết quả xuất hiện trên trang category → ẩn topic list gốc khi
  // đang ở chế độ Bảng/Thẻ (cùng body class với listing-store)
  activate(category) {
    const changed = this.categoryId !== category?.id;
    this.setCategory(category);
    this.resultsActive = true;
    this.syncBodyClass();
    if (changed || !this.loaded) {
      this.page = 0;
      this.fetchResults();
    }
  }

  deactivate() {
    this.resultsActive = false;
    this.syncBodyClass();
  }

  syncBodyClass() {
    const hide = this.resultsActive && this.viewMode !== "native";
    document.body.classList.toggle("sitetor-hide-native-list", hide);
  }
}

const store = new MappingStore();
export default store;
