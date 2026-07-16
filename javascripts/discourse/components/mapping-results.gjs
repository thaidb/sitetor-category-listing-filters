import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { eq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import store, { GROUP_KEYS, groupVocab, groupVocabMap } from "../lib/mapping-store";

// Khu kết quả tuỳ biến trên trang category type Mapping (outlet
// discovery-list-container-top). 3 chế độ xem (persist localStorage):
//   Bảng (mặc định) — cột Tiêu đề + 1 cột/nhóm tag, cell là chip tag
//   Thẻ — grid card: tiêu đề + chip tag tô màu theo nhóm
//   Danh sách gốc — ẩn khu này, hiện lại topic list gốc của Discourse
// "Nhóm theo" (mặc định không nhóm): chọn 1 nhóm → kết quả chia section theo
// từng giá trị tag của nhóm đó (topic nhiều tag xuất hiện ở nhiều section;
// topic không có tag nhóm đó → section "Khác").

function topicUrl(t) {
  return `/t/${t.slug}/${t.id}`;
}

// "Cửa-hàng-thực-phẩm" → "Cửa hàng thực phẩm" (chỉ để hiển thị)
function tagLabel(tag) {
  return tag.replaceAll("-", " ");
}

// giao topic.tags với vocab một nhóm (không phân biệt hoa thường),
// trả về tag ở dạng gốc của vocab
function intersectTags(topicTags, vocabMap) {
  return (topicTags || [])
    .map((t) => vocabMap.get(String(t).toLowerCase()))
    .filter(Boolean);
}

export default class MappingResults extends Component {
  store = store;

  constructor() {
    super(...arguments);
    store.activate(this.args.category);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    store.deactivate();
  }

  // 5 nhóm: nhãn cột/nhóm-theo + map vocab (đọc một lần, settings tĩnh)
  groups = GROUP_KEYS.map((key) => ({
    key,
    label: i18n(themePrefix(`scf.mapping.${key}_short`)),
    vocabMap: groupVocabMap(key),
  }));

  @action
  onCategoryChange() {
    // đổi category trong cùng cây Mapping mà component không bị destroy
    store.activate(this.args.category);
  }

  @action
  setView(mode) {
    store.setViewMode(mode);
  }

  @action
  changeGroupBy(event) {
    store.setGroupBy(event.target.value);
  }

  @action
  prevPage() {
    store.prevPage();
  }

  @action
  nextPage() {
    store.nextPage();
  }

  // mỗi topic → 1 row: cells = tag của topic thuộc từng nhóm (theo thứ tự cột)
  get rows() {
    return this.store.topics.map((t) => ({
      topic: t,
      cells: this.groups.map((g) => ({
        key: g.key,
        tags: intersectTags(t.tags, g.vocabMap),
      })),
    }));
  }

  get isGrouped() {
    return this.store.groupBy !== "none";
  }

  // Nhóm theo section: mỗi giá trị tag của nhóm được chọn → 1 section chứa
  // các topic mang tag đó (topic nhiều tag → nhiều section); topic không có
  // tag nào của nhóm → section "Khác". Không nhóm → 1 section không tiêu đề.
  get sections() {
    const rows = this.rows;
    if (!this.isGrouped) {
      return [{ label: null, rows }];
    }
    const key = this.store.groupBy;
    const cellFor = (row) => row.cells.find((c) => c.key === key);
    const result = [];
    for (const value of groupVocab(key)) {
      const matched = rows.filter((r) => cellFor(r).tags.includes(value));
      if (matched.length) {
        result.push({ label: tagLabel(value), rows: matched });
      }
    }
    const other = rows.filter((r) => cellFor(r).tags.length === 0);
    if (other.length) {
      result.push({
        label: i18n(themePrefix("scf.mapping.other")),
        rows: other,
      });
    }
    return result;
  }

  <template>
    <div
      class="scf-results scf-mapping-results"
      {{didUpdate this.onCategoryChange @category}}
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
            class="scf-view-btn {{if (eq this.store.viewMode 'grid') 'active'}}"
            {{on "click" (fn this.setView "grid")}}
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
          <label class="scf-groupby">
            {{i18n (themePrefix "scf.mapping.group_by")}}
            <select class="scf-select" {{on "change" this.changeGroupBy}}>
              <option value="none" selected={{eq this.store.groupBy "none"}}>
                {{i18n (themePrefix "scf.mapping.group_none")}}
              </option>
              {{#each this.groups as |g|}}
                <option value={{g.key}} selected={{eq this.store.groupBy g.key}}>
                  {{g.label}}
                </option>
              {{/each}}
            </select>
          </label>

          <span class="scf-total">
            {{#if this.store.loading}}
              {{i18n (themePrefix "scf.dang_tai")}}
            {{else}}
              {{i18n
                (themePrefix "scf.mapping.page_info")
                count=this.store.topics.length
                page=this.store.currentPage
              }}
            {{/if}}
          </span>
        {{/unless}}
      </div>

      {{#unless (eq this.store.viewMode "native")}}
        {{#if this.store.loading}}
          <div class="scf-loading"><div class="spinner"></div></div>
        {{else}}

          {{#if this.rows.length}}
            {{#each this.sections as |sec|}}
              {{#if sec.label}}
                <h3 class="scf-section-title">
                  {{sec.label}}
                  <span class="scf-section-count">({{sec.rows.length}})</span>
                </h3>
              {{/if}}

              {{#if (eq this.store.viewMode "table")}}
                <div class="scf-table-wrap">
                  <table class="scf-table scf-mapping-table">
                    <thead>
                      <tr>
                        <th>{{i18n (themePrefix "scf.mapping.title_col")}}</th>
                        {{#each this.groups as |g|}}
                          <th>{{g.label}}</th>
                        {{/each}}
                      </tr>
                    </thead>
                    <tbody>
                      {{#each sec.rows as |r|}}
                        <tr>
                          <td class="scf-map-title">
                            <a href={{topicUrl r.topic}}>{{r.topic.title}}</a>
                          </td>
                          {{#each r.cells as |c|}}
                            <td class="scf-map-cell">
                              {{#if c.tags.length}}
                                {{#each c.tags as |tag|}}
                                  <span
                                    class="scf-chip scf-chip-{{c.key}}"
                                    title={{tag}}
                                  >{{tagLabel tag}}</span>
                                {{/each}}
                              {{else}}
                                <span class="scf-map-none">—</span>
                              {{/if}}
                            </td>
                          {{/each}}
                        </tr>
                      {{/each}}
                    </tbody>
                  </table>
                </div>
              {{else}}
                <div class="scf-cards scf-mapping-cards">
                  {{#each sec.rows as |r|}}
                    <a class="scf-map-card" href={{topicUrl r.topic}}>
                      <h3 class="scf-card-title">{{r.topic.title}}</h3>
                      <div class="scf-map-card-tags">
                        {{#each r.cells as |c|}}
                          {{#each c.tags as |tag|}}
                            <span
                              class="scf-chip scf-chip-{{c.key}}"
                              title={{tag}}
                            >{{tagLabel tag}}</span>
                          {{/each}}
                        {{/each}}
                      </div>
                    </a>
                  {{/each}}
                </div>
              {{/if}}
            {{/each}}
          {{else}}
            <div class="scf-empty">{{i18n (themePrefix "scf.khong_kq")}}</div>
          {{/if}}

          {{! phân trang: latest.json không trả tổng số — prev/next theo
              more_topics_url }}
          {{#if (or this.store.hasPrev this.store.hasNext)}}
            <div class="scf-paging">
              <DButton
                @action={{this.prevPage}}
                @disabled={{unless this.store.hasPrev true}}
                @translatedLabel={{i18n (themePrefix "scf.truoc")}}
              />
              <span class="scf-page scf-page-current">
                {{this.store.currentPage}}
              </span>
              <DButton
                @action={{this.nextPage}}
                @disabled={{unless this.store.hasNext true}}
                @translatedLabel={{i18n (themePrefix "scf.sau")}}
              />
            </div>
          {{/if}}
        {{/if}}
      {{/unless}}
    </div>
  </template>
}
