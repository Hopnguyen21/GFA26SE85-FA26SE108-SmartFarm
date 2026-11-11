// ─────────────────────────────────────────
// Domain Models – SmartFarm Mobile
// Mỗi nhóm model nằm trong một file part ở thư mục parts/:
//   farm · devices · alerts_tasks · ai · automation · crops · inventory · contracts
// Nơi khác chỉ cần import file này.
// ─────────────────────────────────────────
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'geo_polygon.dart';
import '../utils/cron_utils.dart';
import '../utils/json_utils.dart';
export 'geo_polygon.dart';
part 'parts/models_farm.dart';
part 'parts/models_devices.dart';
part 'parts/models_alerts_tasks.dart';
part 'parts/models_ai.dart';
part 'parts/models_automation.dart';
part 'parts/models_crops.dart';
part 'parts/models_inventory.dart';
part 'parts/models_contracts.dart';
