import Component from "@glimmer/component";
import ListingFilterBar from "../../components/listing-filter-bar";
import MappingGroupFilter from "../../components/mapping-group-filter";
import { inCategoryTree } from "../../lib/listing-store";

// Thanh filter BĐS sau breadcrumb:
// - Cây category Listing (settings.listing_category_ids, vd 4033) → thanh
//   filter ĐẦY ĐỦ như trang /listing, kết quả đổ vào khu tuỳ biến
//   (connectors/discovery-list-container-top/sitetor-results.gjs).
// - Cây category Mapping (settings.mapping_category_ids, vd 4034) → filter
//   group-tag đa menu (Nhu cầu/Ngành nghề/Vị trí/Hướng/Góc, vocab từ settings
//   mapping_group_*), lọc giao tag qua latest.json?tags[]=…&match_all_tags,
//   kết quả đổ vào khu tuỳ biến (components/mapping-results.gjs).
export default class SitetorFilters extends Component {
  get category() {
    return this.args.outletArgs?.category;
  }

  get isListing() {
    return inCategoryTree(settings.listing_category_ids, this.category);
  }

  get isMapping() {
    return (
      !this.isListing &&
      inCategoryTree(settings.mapping_category_ids, this.category)
    );
  }

  <template>
    {{#if this.isListing}}
      <ListingFilterBar @category={{this.category}} />
    {{else if this.isMapping}}
      <MappingGroupFilter @category={{this.category}} />
    {{/if}}
  </template>
}
