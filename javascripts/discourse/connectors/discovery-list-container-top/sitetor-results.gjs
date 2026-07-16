import Component from "@glimmer/component";
import ListingResults from "../../components/listing-results";
import { inCategoryTree } from "../../lib/listing-store";

// Khu kết quả tuỳ biến phía trên topic list gốc — trên trang category thuộc
// cây Listing (settings.listing_category_ids) hoặc Mapping
// (settings.mapping_category_ids) cùng render listing-results (Bảng/Thẻ/Danh
// sách gốc, dữ liệu /listing/filter.json). Khác nhau ở @mode:
// - "listing": param từ thanh filter đầy đủ (store tự quản input).
// - "mapping": param custom field đọc từ URL query param (filter legacy) +
//   tags=<csv> từ filter group-tag trong breadcrumb.
// Outlet discovery-list-container-top nằm trong #list-area, ngay trước
// {{yield to="list"}} (core: components/discovery/layout.gjs).
export default class SitetorResults extends Component {
  get category() {
    return this.args.outletArgs?.category;
  }

  get mode() {
    if (!this.category) {
      return null;
    }
    if (inCategoryTree(settings.listing_category_ids, this.category)) {
      return "listing";
    }
    if (inCategoryTree(settings.mapping_category_ids, this.category)) {
      return "mapping";
    }
    return null;
  }

  <template>
    {{#if this.mode}}
      <ListingResults @categoryId={{this.category.id}} @mode={{this.mode}} />
    {{/if}}
  </template>
}
