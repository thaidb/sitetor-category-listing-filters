import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import store from "../lib/listing-store";

// Khu kết quả tuỳ biến trên trang category type Listing (outlet
// discovery-list-container-top). 3 chế độ xem (persist localStorage):
//   Bảng (mặc định) — bảng như /listing
//   Thẻ — grid card kiểu batdongsan (có ảnh, degrade đẹp khi thiếu ảnh)
//   Danh sách gốc — ẩn khu này, hiện lại topic list gốc của Discourse
// Chế độ Bảng/Thẻ ẩn topic list gốc qua body.sitetor-hide-native-list (scss).

// 25000000 → "25 tr" ; 5500000000 → "5,5 tỷ"
function formatPrice(vnd) {
  if (!vnd) {
    return "—";
  }
  const n = Number(vnd);
  if (n >= 1e9) {
    return `${(n / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ`;
  }
  return `${(n / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} tr`;
}

// giá/m² cho card: "X tr/m²" (hoặc tỷ/m² nếu quá lớn)
function pricePerM2(t) {
  const p = Number(t.price);
  const a = Number(t.area);
  if (!p || !a) {
    return null;
  }
  const v = p / a;
  if (v >= 1e9) {
    return `${(v / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ/m²`;
  }
  return `${(v / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} tr/m²`;
}

// "12 Nguyễn Huệ, Bến Nghé, Quận 1"
function address(t) {
  const streetPart = [t.street_number, t.street].filter(Boolean).join(" ");
  return [streetPart, t.ward, t.district].filter(Boolean).join(", ") || "—";
}

function topicUrl(t) {
  return `/t/${t.slug}/${t.id}`;
}

function orDash(v) {
  return v ?? "—";
}

export default class ListingResults extends Component {
  store = store;

  @tracked gotoValue = "";

  constructor() {
    super(...arguments);
    store.activate(this.args.categoryId);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    store.deactivate();
  }

  @action
  onCategoryChange() {
    // đổi category trong cùng cây Listing mà component không bị destroy
    store.activate(this.args.categoryId);
  }

  @action
  setView(mode) {
    store.setViewMode(mode);
  }

  @action
  goPage(p) {
    store.goPage(p);
  }

  @action
  prevPage() {
    store.prevPage();
  }

  @action
  nextPage() {
    store.nextPage();
  }

  @action
  updateGotoValue(event) {
    this.gotoValue = event.target.value;
  }

  @action
  gotoPage() {
    const n = parseInt(this.gotoValue, 10);
    if (!isNaN(n)) {
      store.goPage(n);
      this.gotoValue = "";
    }
  }

  <template>
    <div
      class="scf-results"
      {{didUpdate this.onCategoryChange @categoryId}}
    >
      <div class="scf-results-head">
        <div class="scf-view-toggle">
          <button
            type="button"
            class="scf-view-btn {{if (eq this.store.viewMode 'table') 'active'}}"
            {{on "click" (fn this.setView "table")}}
          >
            {{icon "table-cells"}}
            {{i18n (themePrefix "scf.xem_bang")}}
          </button>
          <button
            type="button"
            class="scf-view-btn {{if (eq this.store.viewMode 'cards') 'active'}}"
            {{on "click" (fn this.setView "cards")}}
          >
            {{icon "images"}}
            {{i18n (themePrefix "scf.xem_the")}}
          </button>
          <button
            type="button"
            class="scf-view-btn {{if (eq this.store.viewMode 'native') 'active'}}"
            {{on "click" (fn this.setView "native")}}
          >
            {{icon "list"}}
            {{i18n (themePrefix "scf.xem_goc")}}
          </button>
        </div>

        {{#unless (eq this.store.viewMode "native")}}
          <span class="scf-total">
            {{#if this.store.loading}}
              {{i18n (themePrefix "scf.dang_tai")}}
            {{else}}
              {{i18n (themePrefix "scf.tong") count=this.store.total}}
              ·
              {{i18n
                (themePrefix "scf.trang")
                page=this.store.currentPage
                total=this.store.totalPages
              }}
            {{/if}}
          </span>
        {{/unless}}
      </div>

      {{#unless (eq this.store.viewMode "native")}}
        {{#if this.store.loading}}
          <div class="scf-loading"><div class="spinner"></div></div>
        {{else}}

          {{#if (eq this.store.viewMode "table")}}
            <div class="scf-table-wrap">
              <table class="scf-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>{{i18n (themePrefix "scf.loai")}}</th>
                    <th>{{i18n (themePrefix "scf.so_nha")}}</th>
                    <th>{{i18n (themePrefix "scf.duong")}}</th>
                    <th>{{i18n (themePrefix "scf.phuong")}}</th>
                    <th>{{i18n (themePrefix "scf.quan")}}</th>
                    <th>{{i18n (themePrefix "scf.gia")}}</th>
                    <th>{{i18n (themePrefix "scf.mat_tien")}}</th>
                    <th>{{i18n (themePrefix "scf.dien_tich")}}</th>
                    <th>{{i18n (themePrefix "scf.huong")}}</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each this.store.topics as |t|}}
                    <tr>
                      <td class="scf-num">
                        <a href={{topicUrl t}} title={{t.title}}>{{t.id}}</a>
                      </td>
                      <td>{{orDash t.type}}</td>
                      <td class="scf-num">{{orDash t.street_number}}</td>
                      <td>
                        <a href={{topicUrl t}} title={{t.title}}>
                          {{orDash t.street}}
                        </a>
                      </td>
                      <td>{{orDash t.ward}}</td>
                      <td>{{orDash t.district}}</td>
                      <td class="scf-num scf-price">{{formatPrice t.price}}</td>
                      <td class="scf-num">{{orDash t.frontage}}</td>
                      <td class="scf-num">{{orDash t.area}}</td>
                      <td>{{orDash t.direction}}</td>
                    </tr>
                  {{else}}
                    <tr>
                      <td colspan="10">
                        {{i18n (themePrefix "scf.khong_kq")}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          {{else}}
            {{! chế độ Thẻ — 95% tin không có ảnh: media strip gọn, giá đỏ dẫn đầu }}
            <div class="scf-cards">
              {{#each this.store.topics as |t|}}
                <a class="scf-card" href={{topicUrl t}}>
                  <div class="scf-card-media {{unless t.image 'no-image'}}">
                    {{#if t.image}}
                      <img src={{t.image}} alt={{t.title}} loading="lazy" />
                    {{else}}
                      {{icon "far-image"}}
                    {{/if}}
                    {{#if t.type}}
                      <span class="scf-card-type">{{t.type}}</span>
                    {{/if}}
                  </div>
                  <div class="scf-card-body">
                    <div class="scf-card-price">
                      {{formatPrice t.price}}
                      {{#if (pricePerM2 t)}}
                        <span class="scf-card-ppm">· {{pricePerM2 t}}</span>
                      {{/if}}
                    </div>
                    <h3 class="scf-card-title">{{t.title}}</h3>
                    <div class="scf-card-specs">
                      {{#if t.area}}
                        <span>{{t.area}} m²</span>
                      {{/if}}
                      {{#if t.frontage}}
                        <span>{{i18n (themePrefix "scf.mt")}} {{t.frontage}} m</span>
                      {{/if}}
                      {{#if t.direction}}
                        <span>{{t.direction}}</span>
                      {{/if}}
                    </div>
                    <div class="scf-card-addr">{{address t}}</div>
                  </div>
                </a>
              {{else}}
                <div class="scf-empty">{{i18n (themePrefix "scf.khong_kq")}}</div>
              {{/each}}
            </div>
          {{/if}}

          {{! phân trang nhảy bước: 1..5 ... 10,15 ... 100,200 ... n }}
          <div class="scf-paging">
            <DButton
              @action={{this.prevPage}}
              @disabled={{unless this.store.hasPrev true}}
              @translatedLabel={{i18n (themePrefix "scf.truoc")}}
            />
            <span class="scf-page-list">
              {{#each this.store.pageList as |p|}}
                {{#if p.current}}
                  <span class="scf-page scf-page-current">{{p.num}}</span>
                {{else}}
                  <button
                    type="button"
                    class="scf-page"
                    {{on "click" (fn this.goPage p.num)}}
                  >{{p.num}}</button>
                {{/if}}
              {{/each}}
            </span>
            <DButton
              @action={{this.nextPage}}
              @disabled={{unless this.store.hasNext true}}
              @translatedLabel={{i18n (themePrefix "scf.sau")}}
            />
            <span class="scf-goto">
              {{i18n (themePrefix "scf.den_trang")}}
              <Input
                @value={{this.gotoValue}}
                @type="number"
                min="1"
                {{on "input" this.updateGotoValue}}
              />
              <DButton
                @action={{this.gotoPage}}
                @translatedLabel={{i18n (themePrefix "scf.di")}}
                class="btn-small"
              />
            </span>
          </div>
        {{/if}}
      {{/unless}}
    </div>
  </template>
}
