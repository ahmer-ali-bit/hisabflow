import 'package:flutter/material.dart';

import 'theme.dart';
import '../features/dashboard/presentation/dashboard_page.dart';

class HisabFlowApp extends StatelessWidget {
  const HisabFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HisabFlow',
        debugShowCheckedModeBanner: false,
        theme: buildHisabTheme(),
        home: const DashboardPage(),
      );
}
