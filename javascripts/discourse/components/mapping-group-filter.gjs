import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import store, { groupVocab } from "../lib/mapping-store";
import ListingMultiSelect from "./listing-multi-select";

// Filter group-tag cho cây category Mapping — render NGAY TRONG breadcrumb
// (connectors/bread-crumbs-right, nối tiếp Home › Mapping › …), kiểu pill gọn.
// 5 nhóm (vocab từ settings mapping_group_*): Nhu cầu (purpose) · Ngành nghề
// (industry, chỉ hiện khi Nhu cầu có Kinh-doanh) · Vị trí (position) · Hướng
// (compass) · Góc (corner). Bấm Lọc → store.apply() đẩy hợp tag vào
// listing-store.tags → khu kết quả (listing-results) refetch
// /listing/filter.json?tags=<csv> (AND với param custom field của filter
// legacy trên URL). Xóa lọc → clear tags.

function toOptions(key) {
  return groupVocab(key).map((v) => ({ value: v }));
}

export default class MappingGroupFilter extends Component {
  store = store;

  // vocab tĩnh từ settings — đọc một lần khi component tạo
  purposeOptions = toOptions("purpose");
  industryOptions = toOptions("industry");
  positionOptions = toOptions("position");
  compassOptions = toOptions("compass");
  cornerOptions = toOptions("corner");

  @action
  setSelection(key, values) {
    store.setSelection(key, values);
  }

  @action
  apply() {
    store.apply();
  }

  @action
  reset() {
    store.reset();
  }

  <template>
    <span class="scf-breadcrumb-group-filter">
      <ListingMultiSelect
        @label={{i18n (themePrefix "scf.mapping.purpose")}}
        @options={{this.purposeOptions}}
        @selected={{this.store.selectedPurpose}}
        @onChange={{fn this.setSelection "purpose"}}
      />

      {{! cascade: Ngành nghề chỉ hiện khi Nhu cầu chọn Kinh-doanh }}
      {{#if this.store.purposeIncludesBusiness}}
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.mapping.industry")}}
          @options={{this.industryOptions}}
          @selected={{this.store.selectedIndustry}}
          @onChange={{fn this.setSelection "industry"}}
          @searchable={{true}}
        />
      {{/if}}

      <ListingMultiSelect
        @label={{i18n (themePrefix "scf.mapping.position")}}
        @options={{this.positionOptions}}
        @selected={{this.store.selectedPosition}}
        @onChange={{fn this.setSelection "position"}}
      />
      <ListingMultiSelect
        @label={{i18n (themePrefix "scf.mapping.compass")}}
        @options={{this.compassOptions}}
        @selected={{this.store.selectedCompass}}
        @onChange={{fn this.setSelection "compass"}}
      />
      <ListingMultiSelect
        @label={{i18n (themePrefix "scf.mapping.corner")}}
        @options={{this.cornerOptions}}
        @selected={{this.store.selectedCorner}}
        @onChange={{fn this.setSelection "corner"}}
      />

      <DButton
        @action={{this.apply}}
        @icon="magnifying-glass"
        @translatedLabel={{i18n (themePrefix "scf.loc")}}
        class="btn-primary scf-btn"
      />
      <DButton
        @action={{this.reset}}
        @translatedLabel={{i18n (themePrefix "scf.xoa")}}
        class="scf-btn"
      />
    </span>
  </template>
}
