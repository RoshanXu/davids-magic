import 'package:flutter_test/flutter_test.dart';

import 'package:david_magic/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DavidMagicApp(isDarkMode: false));
    await tester.pumpAndSettle();

    // 验证标题存在
    expect(find.text('大卫的魔法工具'), findsOneWidget);

    // 验证三个操作按钮存在
    expect(find.text('剪辑'), findsOneWidget);
    expect(find.text('合并'), findsOneWidget);
    expect(find.text('输出'), findsOneWidget);

    // 验证添加文件按钮存在
    expect(find.text('添加文件'), findsOneWidget);
  });
}
