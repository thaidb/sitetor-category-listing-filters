import Component from "@glimmer/component";
import ListingResults from "../../components/listing-results";
import { inCategoryTree } from "../../lib/listing-store";

// Khu kết quả tuỳ biến phía trên topic list gốc — chỉ trên trang category
// thuộc cây Listing (settings.listing_category_ids, vd /c/listing/4033).
// Outlet discovery-list-container-top nằm trong #list-area, ngay trước
// {{yield to="list"}} (core: components/discovery/layout.gjs).
export default class SitetorResults extends Component {
  get category() {
    return this.args.outletArgs?.category;
  }

  get enabled() {
    return (
      this.category &&
      inCategoryTree(settings.listing_category_ids, this.category)
    );
  }

  <template>
    {{#if this.enabled}}
      <ListingResults @categoryId={{this.category.id}} />
    {{/if}}
  </template>
}
