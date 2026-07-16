import Component from "@glimmer/component";
import ListingFilterBar from "../../components/listing-filter-bar";
import MappingFiltersLegacy from "../../components/mapping-filters-legacy";
import { inCategoryTree } from "../../lib/listing-store";

// Thanh filter BĐS sau breadcrumb:
// - Cây category Listing (settings.listing_category_ids, vd 4033) → thanh
//   filter ĐẦY ĐỦ như trang /listing, kết quả đổ vào khu tuỳ biến
//   (connectors/discovery-list-container-top/sitetor-results.gjs).
// - Cây category Mapping (settings.mapping_category_ids) → giữ thanh filter
//   đơn giản bản gốc (query param + TopicQuery custom filters, nhãn Ngân sách).
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
      <MappingFiltersLegacy @category={{this.category}} />
    {{/if}}
  </template>
}
