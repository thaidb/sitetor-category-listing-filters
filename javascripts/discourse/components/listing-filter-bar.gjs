import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import store from "../lib/listing-store";
import ListingMultiSelect from "./listing-multi-select";

// Thanh filter đầy đủ cho category type Listing — replicate bộ field của
// trang /listing (templates/listing.gjs của plugin): q + Loại + cascade
// Tỉnh→Quận→Phường→Đường + Vị trí + Hướng + Giá/Mặt tiền/Diện tích + Sắp xếp.
// Bấm Lọc → store.apply() fetch /listing/filter.json, đổ vào khu kết quả
// (components/listing-results.gjs) — không đụng query param của discovery.
export default class ListingFilterBar extends Component {
  @service siteSettings;

  store = store;

  constructor() {
    super(...arguments);
    store.usdRate = this.siteSettings.sitetor_listing_usd_rate || 26000;
    store.ensureFacets();
  }

  @action
  updateField(name, event) {
    store[name] = event.target.value;
  }

  @action
  setSelection(name, values) {
    store.setSelection(name, values);
  }

  @action
  onQKeydown(event) {
    if (event.key === "Enter") {
      store.apply();
    }
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
    <div class="sitetor-cat-filters scf-full">
      <div class="scf-row">
        <div class="scf-group scf-q">
          <Input
            @value={{this.store.fQ}}
            placeholder={{i18n (themePrefix "scf.tim_kiem")}}
            {{on "keydown" this.onQKeydown}}
          />
        </div>

        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.loai")}}
          @options={{this.store.facets.type}}
          @selected={{this.store.sTypes}}
          @onChange={{fn this.setSelection "sTypes"}}
        />
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.tinh")}}
          @options={{this.store.facets.province}}
          @selected={{this.store.sProvinces}}
          @onChange={{fn this.setSelection "sProvinces"}}
        />
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.quan")}}
          @options={{this.store.facets.district}}
          @selected={{this.store.sDistricts}}
          @onChange={{fn this.setSelection "sDistricts"}}
          @searchable={{true}}
        />
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.phuong")}}
          @options={{this.store.facets.ward}}
          @selected={{this.store.sWards}}
          @onChange={{fn this.setSelection "sWards"}}
          @searchable={{true}}
        />
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.duong")}}
          @options={{this.store.facets.street}}
          @selected={{this.store.sStreets}}
          @onChange={{fn this.setSelection "sStreets"}}
          @searchable={{true}}
        />
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.vi_tri")}}
          @options={{this.store.facets.position}}
          @selected={{this.store.sPositions}}
          @onChange={{fn this.setSelection "sPositions"}}
        />
        <ListingMultiSelect
          @label={{i18n (themePrefix "scf.huong")}}
          @options={{this.store.facets.direction}}
          @selected={{this.store.sDirections}}
          @onChange={{fn this.setSelection "sDirections"}}
        />
      </div>

      <div class="scf-row">
        <span class="scf-group">
          <label>{{i18n (themePrefix "scf.gia")}}</label>
          <Input
            @value={{this.store.fPriceMin}}
            @type="number"
            placeholder="min"
          />
          <span>–</span>
          <Input
            @value={{this.store.fPriceMax}}
            @type="number"
            placeholder="max"
          />
          <select
            class="scf-select scf-unit"
            {{on "change" (fn this.updateField "fPriceUnit")}}
          >
            <option
              value="million"
              selected={{eq this.store.fPriceUnit "million"}}
            >
              {{i18n (themePrefix "scf.trieu")}}
            </option>
            <option
              value="billion"
              selected={{eq this.store.fPriceUnit "billion"}}
            >
              {{i18n (themePrefix "scf.ty")}}
            </option>
            <option value="usd" selected={{eq this.store.fPriceUnit "usd"}}>
              USD
            </option>
          </select>
        </span>

        <span class="scf-group">
          <label>{{i18n (themePrefix "scf.mat_tien")}}</label>
          <Input
            @value={{this.store.fFrontageMin}}
            @type="number"
            placeholder="min"
          />
          <span>–</span>
          <Input
            @value={{this.store.fFrontageMax}}
            @type="number"
            placeholder="max"
          />
        </span>

        <span class="scf-group">
          <label>{{i18n (themePrefix "scf.dien_tich")}}</label>
          <Input
            @value={{this.store.fAreaMin}}
            @type="number"
            placeholder="min"
          />
          <span>–</span>
          <Input
            @value={{this.store.fAreaMax}}
            @type="number"
            placeholder="max"
          />
        </span>

        <span class="scf-group">
          <label>{{i18n (themePrefix "scf.sap_xep")}}</label>
          <select
            class="scf-select"
            {{on "change" (fn this.updateField "fSort")}}
          >
            <option value="new" selected={{eq this.store.fSort "new"}}>
              {{i18n (themePrefix "scf.moi_nhat")}}
            </option>
            <option
              value="price_asc"
              selected={{eq this.store.fSort "price_asc"}}
            >
              {{i18n (themePrefix "scf.gia_tang")}}
            </option>
            <option
              value="price_desc"
              selected={{eq this.store.fSort "price_desc"}}
            >
              {{i18n (themePrefix "scf.gia_giam")}}
            </option>
            <option
              value="area_desc"
              selected={{eq this.store.fSort "area_desc"}}
            >
              {{i18n (themePrefix "scf.dien_tich_giam")}}
            </option>
          </select>
        </span>

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
      </div>
    </div>
  </template>
}
