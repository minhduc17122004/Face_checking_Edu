import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class ChooseDb extends StatelessWidget {
  final List<String> dbList;
  const ChooseDb({super.key, required this.dbList});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DefaultAppBar(
        title: const Text('Chọn Database'),
      ),
      backgroundColor: AppColors.white,
      body: dbList.isEmpty
          ? const _EmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Chọn database để tiếp tục',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: dbList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final dbName = dbList[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.storage),
                          ),
                          title: Text(
                            dbName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await getIt<LocalService>().saveOdooDbName(dbName);
                            AppNavigator.pushNamedAndRemoveUntil(
                              RouterName.login,
                              (_) => false,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storage_outlined,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy database',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng kiểm tra lại cấu hình hoặc thử lại sau.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
