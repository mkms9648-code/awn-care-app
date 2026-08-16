import 'package:flutter_test/flutter_test.dart';

import 'package:awn_care/config/app_config.dart';

void main() {
  test('App config has correct platform identifier', () {
    expect(AppConfig.platform, 'mobile');
  });

  test('RPC function names match integration contract', () {
    expect(AppConfig.rpcResolveStaff, 'app_resolve_staff');
    expect(AppConfig.rpcEncounterList, 'app_encounter_list');
    expect(AppConfig.rpcPatientSummary, 'app_patient_summary');
    expect(AppConfig.rpcVitalsSeries, 'app_vitals_series');
  });
}
