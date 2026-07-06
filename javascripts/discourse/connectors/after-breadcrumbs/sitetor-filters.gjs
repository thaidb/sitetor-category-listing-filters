import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { eq } from "truth-helpers";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

// Thanh filter BĐS sau breadcrumb — chỉ hiện trong cây category Listing/Mapping.
// Giá trị đẩy vào query param của discovery route; backend plugin sitetor-listing
// (TopicQuery custom filters) lọc server-side nên phân trang/đếm đều đúng.
// đồng bộ đơn vị với trang /listing (controllers/listing.js của plugin)
const PRICE_UNITS = { million: 1e6, billion: 1e9 };

export default class SitetorFilters extends Component {
  @service router;
  @service siteSettings;

  @tracked facets = null;
  @tracked type = "";
  @tracked position = "";
  @tracked direction = "";
  @tracked priceUnit = "million";
  @tracked priceMin = "";
  @tracked priceMax = "";
  @tracked frontageMin = "";
  @tracked frontageMax = "";
  @tracked areaMin = "";
  @tracked areaMax = "";

  constructor() {
    super(...arguments);
    if (!this.enabled) {
      return;
    }
    this.#initFromUrl();
    ajax("/listing/facets.json")
      .then((f) => (this.facets = f))
      .catch(() => (this.facets = null));
  }

  #initFromUrl() {
    const qp = this.router.currentRoute?.queryParams || {};
    this.type = qp.type || "";
    this.position = qp.position || "";
    this.direction = qp.direction || "";
    // suy đơn vị hiển thị từ độ lớn giá trên URL (VND): >= 1 tỷ → tỷ, còn lại triệu
    const raw = Number(qp.price_min || qp.price_max || 0);
    this.priceUnit = raw >= 1e9 ? "billion" : "million";
    const div = PRICE_UNITS[this.priceUnit];
    this.priceMin = qp.price_min ? String(Number(qp.price_min) / div) : "";
    this.priceMax = qp.price_max ? String(Number(qp.price_max) / div) : "";
    this.frontageMin = qp.frontage_min || "";
    this.frontageMax = qp.frontage_max || "";
    this.areaMin = qp.area_min || "";
    this.areaMax = qp.area_max || "";
  }

  #inTree(csv) {
    const ids = (csv || "")
      .split("|")
      .map((x) => parseInt(x, 10))
      .filter(Boolean);
    let c = this.args.outletArgs?.category;
    while (c) {
      if (ids.includes(c.id)) {
        return true;
      }
      c = c.parentCategory;
    }
    return false;
  }

  get isMapping() {
    return this.#inTree(settings.mapping_category_ids);
  }

  get enabled() {
    return this.#inTree(settings.listing_category_ids) || this.isMapping;
  }

  get priceLabel() {
    return i18n(themePrefix(this.isMapping ? "scf.ngan_sach" : "scf.gia"));
  }

  get typeOptions() {
    return this.facets?.type || [];
  }

  get positionOptions() {
    return this.facets?.position || [];
  }

  get directionOptions() {
    return this.facets?.direction || [];
  }

  @action
  setSelect(field, event) {
    this[field] = event.target.value;
  }

  get priceMultiplier() {
    if (this.priceUnit === "usd") {
      return this.siteSettings.sitetor_listing_usd_rate || 26000;
    }
    return PRICE_UNITS[this.priceUnit] || 1e6;
  }

  @action
  apply() {
    const v = (x) => (x === "" || x === null || x === undefined ? null : x);
    const trieu = (x) =>
      x === "" || x === null
        ? null
        : String(Math.round(Number(x) * this.priceMultiplier));
    this.router.transitionTo({
      queryParams: {
        type: v(this.type),
        position: v(this.position),
        direction: v(this.direction),
        price_min: trieu(this.priceMin),
        price_max: trieu(this.priceMax),
        frontage_min: v(this.frontageMin),
        frontage_max: v(this.frontageMax),
        area_min: v(this.areaMin),
        area_max: v(this.areaMax),
      },
    });
  }

  @action
  reset() {
    this.type = "";
    this.position = "";
    this.direction = "";
    this.priceUnit = "million";
    this.priceMin = "";
    this.priceMax = "";
    this.frontageMin = "";
    this.frontageMax = "";
    this.areaMin = "";
    this.areaMax = "";
    this.apply();
  }

  <template>
    {{#if this.enabled}}
      <div class="sitetor-cat-filters">
        <select
          class="scf-select"
          {{on "change" (fn this.setSelect "type")}}
        >
          <option value="">{{i18n (themePrefix "scf.loai")}}</option>
          {{#each this.typeOptions as |o|}}
            <option value={{o.value}} selected={{eq o.value this.type}}>
              {{o.value}}
            </option>
          {{/each}}
        </select>

        <select
          class="scf-select"
          {{on "change" (fn this.setSelect "position")}}
        >
          <option value="">{{i18n (themePrefix "scf.vi_tri")}}</option>
          {{#each this.positionOptions as |o|}}
            <option value={{o.value}} selected={{eq o.value this.position}}>
              {{o.value}}
            </option>
          {{/each}}
        </select>

        <span class="scf-group">
          <label>{{this.priceLabel}}</label>
          <Input @value={{this.priceMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{this.priceMax}} @type="number" placeholder="max" />
          <select
            class="scf-select scf-unit"
            {{on "change" (fn this.setSelect "priceUnit")}}
          >
            <option value="million" selected={{eq this.priceUnit "million"}}>
              {{i18n (themePrefix "scf.trieu")}}
            </option>
            <option value="billion" selected={{eq this.priceUnit "billion"}}>
              {{i18n (themePrefix "scf.ty")}}
            </option>
            <option value="usd" selected={{eq this.priceUnit "usd"}}>
              USD
            </option>
          </select>
        </span>

        <span class="scf-group">
          <label>{{i18n (themePrefix "scf.mat_tien")}}</label>
          <Input @value={{this.frontageMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{this.frontageMax}} @type="number" placeholder="max" />
        </span>

        <span class="scf-group">
          <label>{{i18n (themePrefix "scf.dien_tich")}}</label>
          <Input @value={{this.areaMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{this.areaMax}} @type="number" placeholder="max" />
        </span>

        <select
          class="scf-select"
          {{on "change" (fn this.setSelect "direction")}}
        >
          <option value="">{{i18n (themePrefix "scf.huong")}}</option>
          {{#each this.directionOptions as |o|}}
            <option value={{o.value}} selected={{eq o.value this.direction}}>
              {{o.value}}
            </option>
          {{/each}}
        </select>

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
    {{/if}}
  </template>
}
