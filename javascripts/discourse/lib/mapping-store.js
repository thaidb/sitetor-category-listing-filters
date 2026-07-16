import { tracked } from "@glimmer/tracking";
import listingStore from "./listing-store";

// Store lựa chọn group-tag cho cây category Mapping — dùng bởi filter
// group-tag trong breadcrumb (connectors/bread-crumbs-right). Chỉ giữ state
// 5 nhóm + cascade; bấm Lọc → đẩy hợp tag vào listing-store (store.tags),
// khu kết quả dùng chung với Listing fetch /listing/filter.json?tags=<csv>
// (giao AND phía server, kết hợp AND với các param custom field trên URL
// do mapping-filters-legacy đặt).

// tag "chốt" cascade: menu Ngành nghề chỉ hiện khi Nhu cầu chọn Kinh-doanh
export const BUSINESS_PURPOSE_TAG = "Kinh-doanh";

// vocab một nhóm từ settings mapping_group_<key> (list type → chuỗi "a|b|c")
export function groupVocab(key) {
  const raw = settings[`mapping_group_${key}`] || "";
  return raw
    .split("|")
    .map((v) => v.trim())
    .filter(Boolean);
}

class MappingGroupStore {
  // lựa chọn tạm theo nhóm — chỉ áp vào listing-store.tags khi bấm Lọc
  @tracked selectedPurpose = [];
  @tracked selectedIndustry = [];
  @tracked selectedPosition = [];
  @tracked selectedCompass = [];
  @tracked selectedCorner = [];

  selectionField(key) {
    return `selected${key.charAt(0).toUpperCase()}${key.slice(1)}`;
  }

  // cascade: Nhu cầu có Kinh-doanh → mở menu Ngành nghề
  get purposeIncludesBusiness() {
    return this.selectedPurpose.some(
      (t) => t.toLowerCase() === BUSINESS_PURPOSE_TAG.toLowerCase()
    );
  }

  // hợp tất cả tag đang chọn của 5 nhóm → tags=<csv> (AND phía server)
  get selectedTags() {
    return [
      ...this.selectedPurpose,
      ...this.selectedIndustry,
      ...this.selectedPosition,
      ...this.selectedCompass,
      ...this.selectedCorner,
    ];
  }

  setSelection(key, values) {
    this[this.selectionField(key)] = values;
    // cascade: bỏ Kinh-doanh khỏi Nhu cầu → xoá lựa chọn Ngành nghề (menu ẩn,
    // không để tag ngành "kẹt" lại trong query)
    if (key === "purpose" && !this.purposeIncludesBusiness) {
      this.selectedIndustry = [];
    }
  }

  apply() {
    listingStore.setTags(this.selectedTags);
  }

  reset() {
    this.selectedPurpose = [];
    this.selectedIndustry = [];
    this.selectedPosition = [];
    this.selectedCompass = [];
    this.selectedCorner = [];
    listingStore.setTags([]);
  }
}

const store = new MappingGroupStore();
export default store;
