import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

// Store dùng chung giữa thanh filter (connector after-breadcrumbs) và khu
// kết quả tuỳ biến (connector discovery-list-container-top) trên trang
// category type Listing VÀ Mapping — cùng fetch /listing/filter.json:
// - mode "listing": tự quản lý input filter (không đi qua query param).
// - mode "mapping": param custom field đọc từ URL query param (do
//   mapping-filters-legacy đặt qua router.transitionTo) + tags=<csv> từ
//   filter group-tag trong breadcrumb — hai nguồn kết hợp AND trong một fetch.

const PRICE_UNITS = { million: 1e6, billion: 1e9 };
const VIEW_KEY = "sitetor-clf-view-mode";
const VIEW_MODES = ["table", "cards", "native"];

// param custom field trên URL (whitelist trùng api-initializer +
// TopicQuery.add_custom_filter của plugin sitetor-listing)
const URL_FILTER_PARAMS = [
  "type",
  "position",
  "direction",
  "price_min",
  "price_max",
  "frontage_min",
  "frontage_max",
  "area_min",
  "area_max",
];

export function inCategoryTree(csv, category) {
  const ids = (csv || "")
    .split("|")
    .map((x) => parseInt(x, 10))
    .filter(Boolean);
  let c = category;
  while (c) {
    if (ids.includes(c.id)) {
      return true;
    }
    c = c.parentCategory;
  }
  return false;
}

function readViewMode() {
  try {
    const v = localStorage.getItem(VIEW_KEY);
    return VIEW_MODES.includes(v) ? v : "table";
  } catch {
    return "table";
  }
}

class ListingStore {
  @tracked categoryId = null;
  mode = "listing"; // "listing" | "mapping"

  // input tạm — chỉ áp vào appliedParams khi bấm Lọc (mirror controllers/listing.js)
  @tracked fQ = "";
  @tracked fPriceMin = "";
  @tracked fPriceMax = "";
  @tracked fPriceUnit = "million"; // million | billion | usd
  @tracked fFrontageMin = "";
  @tracked fFrontageMax = "";
  @tracked fAreaMin = "";
  @tracked fAreaMax = "";
  @tracked fSort = "new";
  @tracked sTypes = [];
  @tracked sPositions = [];
  @tracked sDirections = [];
  @tracked sProvinces = [];
  @tracked sDistricts = [];
  @tracked sWards = [];
  @tracked sStreets = [];

  // filter đã áp dụng — giữ nguyên khi chuyển trang (mode listing)
  appliedParams = {};

  // group-tag đã áp dụng (mode mapping) — filter breadcrumb set qua setTags()
  @tracked tags = [];

  // kết quả từ /listing/filter.json
  @tracked topics = [];
  @tracked total = 0;
  @tracked page = 0; // 0-based (giống plugin)
  @tracked perPage = 30;
  @tracked loading = false;
  @tracked loaded = false;

  // facets từ /listing/facets.json (phường/đường cascade theo quận đã chọn)
  @tracked facets = {};

  @tracked viewMode = readViewMode();

  usdRate = 26000;
  resultsActive = false;
  #facetsRequested = false;
  #fetchSeq = 0;
  #lastUrlKey = null;

  get totalPages() {
    return Math.max(1, Math.ceil(this.total / this.perPage));
  }

  get currentPage() {
    return Number(this.page) + 1; // hiển thị 1-based
  }

  get hasPrev() {
    return this.currentPage > 1;
  }

  get hasNext() {
    return this.currentPage < this.totalPages;
  }

  // Phân trang nhảy bước: 1..5, 10,15..95, 100,200..., n (mirror /listing)
  get pageList() {
    const n = this.totalPages;
    const pages = new Set();
    for (let i = 1; i <= Math.min(5, n); i++) {
      pages.add(i);
    }
    for (let i = 10; i < Math.min(100, n); i += 5) {
      pages.add(i);
    }
    for (let i = 100; i <= n; i += 100) {
      pages.add(i);
    }
    pages.add(n);
    pages.add(this.currentPage);
    return [...pages]
      .sort((a, b) => a - b)
      .map((p) => ({ num: p, current: p === this.currentPage }));
  }

  ensureFacets() {
    if (!this.#facetsRequested) {
      this.loadFacets();
    }
  }

  async loadFacets() {
    this.#facetsRequested = true;
    const data = {};
    if (this.sDistricts.length) {
      data.district = this.sDistricts.join(",");
    }
    try {
      this.facets = await ajax("/listing/facets.json", { data });
    } catch {
      this.facets = {};
    }
  }

  priceToVnd(v) {
    if (v === "" || v === null || v === undefined) {
      return null;
    }
    const rate =
      this.fPriceUnit === "usd"
        ? this.usdRate
        : PRICE_UNITS[this.fPriceUnit] || 1e6;
    return Math.round(Number(v) * rate);
  }

  collectFilterParams() {
    const num = (v) => (v === "" || v === null ? null : Number(v));
    const csv = (arr) => (arr.length ? arr.join(",") : null);
    return {
      q: this.fQ || null,
      price_min: this.priceToVnd(this.fPriceMin),
      price_max: this.priceToVnd(this.fPriceMax),
      frontage_min: num(this.fFrontageMin),
      frontage_max: num(this.fFrontageMax),
      area_min: num(this.fAreaMin),
      area_max: num(this.fAreaMax),
      sort: this.fSort === "new" ? null : this.fSort,
      type: csv(this.sTypes),
      position: csv(this.sPositions),
      direction: csv(this.sDirections),
      province: csv(this.sProvinces),
      district: csv(this.sDistricts),
      ward: csv(this.sWards),
      street: csv(this.sStreets),
    };
  }

  // param custom field hiện có trên URL (mode mapping — do
  // mapping-filters-legacy đặt qua router.transitionTo)
  readUrlFilterParams() {
    const out = {};
    const qp = new URLSearchParams(window.location.search);
    for (const k of URL_FILTER_PARAMS) {
      const v = qp.get(k);
      if (v !== null && v !== "") {
        out[k] = v;
      }
    }
    return out;
  }

  #urlFilterKey() {
    const p = this.readUrlFilterParams();
    return URL_FILTER_PARAMS.map((k) => `${k}=${p[k] ?? ""}`).join("&");
  }

  async fetchResults() {
    if (!this.categoryId) {
      return;
    }
    const seq = ++this.#fetchSeq;
    this.loading = true;
    const data = { category_id: this.categoryId, page: this.page };
    if (this.mode === "mapping") {
      // custom field từ URL (filter legacy) + tags từ filter breadcrumb — AND
      Object.assign(data, this.readUrlFilterParams());
      this.#lastUrlKey = this.#urlFilterKey();
      if (this.tags.length) {
        data.tags = this.tags.join(",");
      }
    } else {
      for (const [k, v] of Object.entries(this.appliedParams)) {
        if (v !== null && v !== undefined && v !== "") {
          data[k] = v;
        }
      }
    }
    try {
      const r = await ajax("/listing/filter.json", { data });
      if (seq !== this.#fetchSeq) {
        return; // đã có request mới hơn
      }
      this.topics = r.topics || [];
      this.total = r.total || 0;
      this.perPage = r.per_page || this.perPage;
      this.loaded = true;
    } catch {
      if (seq === this.#fetchSeq) {
        this.topics = [];
        this.total = 0;
        this.loaded = true;
      }
    } finally {
      if (seq === this.#fetchSeq) {
        this.loading = false;
      }
    }
  }

  setSelection(name, values) {
    this[name] = values;
    if (name === "sDistricts") {
      // cascade: đổi quận → nạp lại danh sách phường/đường
      this.sWards = [];
      this.sStreets = [];
      this.loadFacets();
    }
  }

  apply() {
    this.appliedParams = this.collectFilterParams();
    this.page = 0;
    // đang xem danh sách gốc mà bấm Lọc → chuyển sang bảng để thấy kết quả
    if (this.viewMode === "native") {
      this.setViewMode("table");
    }
    this.fetchResults();
  }

  // filter group-tag (breadcrumb, mode mapping) bấm Lọc/Xóa lọc
  setTags(tags) {
    this.tags = tags || [];
    this.page = 0;
    if (this.viewMode === "native") {
      this.setViewMode("table");
    }
    this.fetchResults();
  }

  // mode mapping: filter legacy đổi query param URL (routeDidChange) →
  // refetch nếu bộ param custom field thực sự thay đổi
  maybeRefetchFromUrl() {
    if (this.mode !== "mapping" || !this.resultsActive) {
      return;
    }
    if (this.#urlFilterKey() !== this.#lastUrlKey) {
      this.page = 0;
      this.fetchResults();
    }
  }

  reset() {
    this.fQ = "";
    this.fPriceMin =
      this.fPriceMax =
      this.fFrontageMin =
      this.fFrontageMax =
      this.fAreaMin =
      this.fAreaMax =
        "";
    this.fPriceUnit = "million";
    this.fSort = "new";
    this.sTypes = [];
    this.sPositions = [];
    this.sDirections = [];
    this.sProvinces = [];
    this.sDistricts = [];
    this.sWards = [];
    this.sStreets = [];
    this.appliedParams = {};
    this.page = 0;
    this.fetchResults();
    this.loadFacets();
  }

  goPage(p) {
    const n = Math.min(Math.max(p, 1), this.totalPages);
    this.page = n - 1;
    this.fetchResults();
  }

  prevPage() {
    if (this.hasPrev) {
      this.goPage(this.currentPage - 1);
    }
  }

  nextPage() {
    if (this.hasNext) {
      this.goPage(this.currentPage + 1);
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

  // khu kết quả xuất hiện trên trang category → ẩn topic list gốc khi
  // đang ở chế độ Bảng/Thẻ
  activate(categoryId, mode = "listing") {
    const changed = this.categoryId !== categoryId || this.mode !== mode;
    this.categoryId = categoryId;
    this.mode = mode;
    this.resultsActive = true;
    this.syncBodyClass();
    if (changed || !this.loaded) {
      this.page = 0;
      this.fetchResults();
    }
    if (mode === "listing") {
      this.ensureFacets();
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

const store = new ListingStore();
export default store;
