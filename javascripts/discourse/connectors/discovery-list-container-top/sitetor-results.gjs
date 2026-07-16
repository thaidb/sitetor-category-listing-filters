import Component from "@glimmer/component";
import ListingResults from "../../components/listing-results";
import MappingResults from "../../components/mapping-results";
import { inCategoryTree } from "../../lib/listing-store";

// Khu kết quả tuỳ biến phía trên topic list gốc — trên trang category:
// - Cây Listing (settings.listing_category_ids, vd 4033) → listing-results
//   (bảng/thẻ từ /listing/filter.json).
// - Cây Mapping (settings.mapping_category_ids, vd 4034) → mapping-results
//   (bảng cột-theo-nhóm-tag / thẻ / nhóm theo section, từ latest.json?tags[]).
// Outlet discovery-list-container-top nằm trong #list-area, ngay trước
// {{yield to="list"}} (core: components/discovery/layout.gjs).
export default class SitetorResults extends Component {
  get category() {
    return this.args.outletArgs?.category;
  }

  get isListing() {
    return (
      this.category &&
      inCategoryTree(settings.listing_category_ids, this.category)
    );
  }

  get isMapping() {
    return (
      this.category &&
      !this.isListing &&
      inCategoryTree(settings.mapping_category_ids, this.category)
    );
  }

  <template>
    {{#if this.isListing}}
      <ListingResults @categoryId={{this.category.id}} />
    {{else if this.isMapping}}
      <MappingResults @category={{this.category}} />
    {{/if}}
  </template>
}
