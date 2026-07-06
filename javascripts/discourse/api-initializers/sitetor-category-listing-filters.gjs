import { apiInitializer } from "discourse/lib/api";

// Đăng ký query param cho discovery route — backend plugin sitetor-listing
// whitelist cùng bộ tên này qua TopicQuery.add_custom_filter.
const PARAMS = [
  "type",
  "position",
  "direction",
  "price_min",
  "price_max",
  "frontage_min",
  "frontage_max",
  "area_min",
  "area_max",
];

export default apiInitializer((api) => {
  PARAMS.forEach((p) =>
    api.addDiscoveryQueryParam(p, { replace: true, refreshModel: true })
  );
});
