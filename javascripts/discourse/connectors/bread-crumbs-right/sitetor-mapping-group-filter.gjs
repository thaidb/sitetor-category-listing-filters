import Component from "@glimmer/component";
import MappingGroupFilter from "../../components/mapping-group-filter";
import { inCategoryTree } from "../../lib/listing-store";

// Filter group-tag nối tiếp breadcrumb — outlet bread-crumbs-right là
// PluginOutlet nằm TRONG <ol class="category-breadcrumb"> (connectorTagName
// "li", sau CategoryDrop/TagDrop; core:
// frontend/discourse/app/components/bread-crumbs.gjs). Chỉ hiện trên trang
// category thuộc cây Mapping (settings.mapping_category_ids); outletArgs cho
// category hiện tại qua currentCategory.
export default class SitetorMappingGroupFilter extends Component {
  get category() {
    return this.args.outletArgs?.currentCategory;
  }

  get isMapping() {
    return (
      this.category &&
      !inCategoryTree(settings.listing_category_ids, this.category) &&
      inCategoryTree(settings.mapping_category_ids, this.category)
    );
  }

  <template>
    {{#if this.isMapping}}
      <MappingGroupFilter />
    {{/if}}
  </template>
}
