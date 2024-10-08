import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:flutter/material.dart';

Widget fontSettings = StatefulBuilder(
  builder: (context, setState) => SingleChildScrollView(
    child: Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          screenTimeout(context, setState),
        ],
      ),
    ),
  ),
);

Widget screenTimeout(BuildContext context, StateSetter setState) {
  return Padding(
    padding: const EdgeInsets.only(left: 10.0, right: 10.0),
    child: ListTile(
      title: Text(L10n.of(context).reading_page_screen_timeout),
      leadingAndTrailingTextStyle: TextStyle(
        fontSize: 16,
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      subtitle: Row(
        children: [
          Text(L10n.of(context).common_minutes(Prefs().awakeTime)),
          Expanded(
            child: Slider(
                min: 0,
                max: 60,
                label: Prefs().awakeTime.toString(),
                value: Prefs().awakeTime.toDouble(),
                onChangeEnd: (value) => setState(() {
                      readingPageKey.currentState!.setAwakeTimer(value.toInt());
                    }),
                onChanged: (value) => setState(() {
                      Prefs().awakeTime = value.toInt();
                    })),
          ),
        ],
      ),
    ),
  );
}
