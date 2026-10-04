import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Every icon the app uses, from Material Symbols **Rounded** (DS §4),
/// weight 400 at 24 dp. Use `Icon(SaartheeIcons.x)`; pass `fill: 1` for the
/// filled variant (selected nav tab, Report "+"). No `Icons.*` in app code.
class SaartheeIcons {
  const SaartheeIcons._();

  /// Default weight / optical size for every glyph.
  static const double weight = 400;
  static const double fillOff = 0;
  static const double fillOn = 1;

  // Navigation (DS §5 bottom navigation).
  static const IconData navHome = Symbols.home_rounded;
  static const IconData navMap = Symbols.map_rounded;
  static const IconData navReport = Symbols.add_circle_rounded;
  static const IconData navAlerts = Symbols.notifications_rounded;
  static const IconData navMyWard = Symbols.location_city_rounded;

  // Statuses (DS §2).
  static const IconData statusReported = Symbols.radio_button_unchecked_rounded;
  static const IconData statusAcknowledged = Symbols.mark_email_read_rounded;
  static const IconData statusInProgress = Symbols.construction_rounded;
  static const IconData statusFixed = Symbols.check_circle_rounded;
  static const IconData statusVerified = Symbols.verified_rounded;
  static const IconData statusReopened = Symbols.replay_rounded;
  static const IconData statusRejected = Symbols.block_rounded;

  // Severities (DS §2).
  static const IconData severityInfo = Symbols.info_rounded;
  static const IconData severityAdvisory = Symbols.campaign_rounded;
  static const IconData severityWarning = Symbols.warning_rounded;
  static const IconData severityCritical = Symbols.emergency_rounded;

  // Categories (DS §2).
  static const IconData catRoads = Symbols.road_rounded;
  static const IconData catWater = Symbols.water_drop_rounded;
  static const IconData catDrainage = Symbols.water_damage_rounded;
  static const IconData catGarbage = Symbols.delete_rounded;
  static const IconData catStreetlight = Symbols.lightbulb_rounded;
  static const IconData catTrees = Symbols.park_rounded;
  static const IconData catAnimals = Symbols.pets_rounded;
  static const IconData catHealth = Symbols.pest_control_rounded;
  static const IconData catToilets = Symbols.wc_rounded;
  static const IconData catEncroachment = Symbols.do_not_step_rounded;
  static const IconData catTraffic = Symbols.traffic_rounded;
  static const IconData catProperty = Symbols.receipt_long_rounded;
  static const IconData catBuilding = Symbols.apartment_rounded;
  static const IconData catOther = Symbols.more_horiz_rounded;

  // Actions and UI.
  static const IconData add = Symbols.add_rounded;
  static const IconData addPhoto = Symbols.add_a_photo_rounded;
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData forward = Symbols.arrow_forward_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData searchOff = Symbols.search_off_rounded;
  static const IconData myLocation = Symbols.my_location_rounded;
  static const IconData locationOff = Symbols.location_off_rounded;
  static const IconData location = Symbols.location_on_rounded;
  static const IconData language = Symbols.translate_rounded;
  static const IconData settings = Symbols.settings_rounded;
  static const IconData darkMode = Symbols.dark_mode_rounded;
  static const IconData animation = Symbols.animation_rounded;
  static const IconData offline = Symbols.cloud_off_rounded;
  static const IconData error = Symbols.error_rounded;
  static const IconData errorOutline = Symbols.error_rounded;
  static const IconData warning = Symbols.warning_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData success = Symbols.check_circle_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData camera = Symbols.photo_camera_rounded;
  static const IconData visibility = Symbols.visibility_rounded;
  static const IconData visibilityOff = Symbols.visibility_off_rounded;
  static const IconData logout = Symbols.logout_rounded;
  static const IconData lock = Symbols.lock_rounded;
  static const IconData lockClock = Symbols.lock_clock_rounded;
  static const IconData person = Symbols.person_rounded;
  static const IconData personOff = Symbols.person_off_rounded;
  static const IconData group = Symbols.group_rounded;
  static const IconData download = Symbols.download_rounded;
  static const IconData copy = Symbols.content_copy_rounded;
  static const IconData share = Symbols.share_rounded;
  static const IconData taskAlt = Symbols.task_alt_rounded;
  static const IconData description = Symbols.description_rounded;
  static const IconData editNote = Symbols.edit_note_rounded;
  static const IconData dragHandle = Symbols.drag_handle_rounded;
  static const IconData send = Symbols.send_rounded;
  static const IconData pause = Symbols.pause_rounded;
  static const IconData pauseCircle = Symbols.pause_circle_rounded;
  static const IconData play = Symbols.play_arrow_rounded;
  static const IconData image = Symbols.image_rounded;
  static const IconData brokenImage = Symbols.broken_image_rounded;
  static const IconData hideImage = Symbols.hide_image_rounded;
  static const IconData imageMissing = Symbols.image_not_supported_rounded;
  static const IconData factCheck = Symbols.fact_check_rounded;
  static const IconData insights = Symbols.insights_rounded;
  static const IconData listAlt = Symbols.list_alt_rounded;
  static const IconData qrCode = Symbols.qr_code_rounded;
  static const IconData category = Symbols.category_rounded;
  static const IconData hourglass = Symbols.hourglass_top_rounded;
  static const IconData chat = Symbols.chat_rounded;
  static const IconData filterOff = Symbols.filter_alt_off_rounded;
  static const IconData linkOff = Symbols.link_off_rounded;
  static const IconData devices = Symbols.devices_rounded;
  static const IconData cancel = Symbols.cancel_rounded;
  static const IconData radioOn = Symbols.radio_button_checked_rounded;
  static const IconData radioOff = Symbols.radio_button_unchecked_rounded;
  static const IconData more = Symbols.more_horiz_rounded;
  static const IconData schedule = Symbols.schedule_rounded;
  static const IconData construction = Symbols.construction_rounded;
  static const IconData notifications = Symbols.notifications_rounded;
  static const IconData thumbUp = Symbols.thumb_up_rounded;
  static const IconData flag = Symbols.flag_rounded;
  static const IconData message = Symbols.chat_rounded;
  static const IconData election = Symbols.how_to_vote_rounded;
  static const IconData report = Symbols.add_circle_rounded;
  static const IconData photo = Symbols.photo_camera_rounded;
  static const IconData follow = Symbols.notifications_active_rounded;
  static const IconData inbox = Symbols.inbox_rounded;
  static const IconData park = Symbols.park_rounded;

  // Admin console (v1, restyled).
  static const IconData block = Symbols.block_rounded;

  // TASK-04 accounts (append-only).
  static const IconData delete = Symbols.delete_rounded;
  static const IconData privacy = Symbols.shield_person_rounded;
  static const IconData phone = Symbols.smartphone_rounded;

  // TASK-12 services and initiatives (append-only).
  static const IconData globe = Symbols.language_rounded;
  static const IconData apartment = Symbols.apartment_rounded;
  static const IconData event = Symbols.event_rounded;
  static const IconData cleaning = Symbols.cleaning_services_rounded;
  static const IconData medical = Symbols.medical_services_rounded;
  static const IconData openInNew = Symbols.open_in_new_rounded;
  static const IconData call = Symbols.call_rounded;
  static const IconData receipt = Symbols.receipt_long_rounded;
  static const IconData badge = Symbols.badge_rounded;
  static const IconData attractions = Symbols.attractions_rounded;
  static const IconData services = Symbols.home_repair_service_rounded;

  // TASK-05 report fixes (append-only): pin nudge arrows, adjust pin.
  static const IconData arrowUp = Symbols.arrow_upward_rounded;
  static const IconData arrowDown = Symbols.arrow_downward_rounded;
  static const IconData editLocation = Symbols.edit_location_alt_rounded;
  // TASK-10 staff console (additive).
  static const IconData dashboard = Symbols.dashboard_rounded;
  static const IconData menu = Symbols.menu_rounded;
  static const IconData moderation = Symbols.shield_rounded;
  static const IconData merge = Symbols.merge_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData adminPanel = Symbols.admin_panel_settings_rounded;
}
