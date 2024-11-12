// lib/widgets/user_container.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/status_provider.dart';
import 'user_status_widget.dart'; // fetchUserWorkplaces 함수 임포트

class UserContainer extends StatelessWidget {
  const UserContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 위치 표시 부분
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    '삼성동',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // 상태 컨테이너 (좌우 및 세로 스크롤)
          Center(
            child: SizedBox(
              width: 185,
              height: 50,
              child: FutureBuilder<List<List<WorkplaceData>>>(
                future: fetchUserWorkplaces(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(color: Colors.white);
                  } else if (snapshot.hasError) {
                    return const Text('오류 발생', style: TextStyle(color: Colors.white));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('데이터가 없습니다.', style: TextStyle(color: Colors.white));
                  } else {
                    return PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: snapshot.data!.length,
                      onPageChanged: (verticalIndex) {
                        final group = snapshot.data![verticalIndex];
                        // 세로 스크롤 시 첫 번째 가로 요소로 텍스트 업데이트
                        Provider.of<StatusProvider>(context, listen: false)
                            .setCurrentText(group[0].data[3]);
                      },
                      itemBuilder: (context, verticalIndex) {
                        final group = snapshot.data![verticalIndex];
                        final pageController = PageController(initialPage: 3);

                        return PageView.builder(
                          controller: pageController,
                          scrollDirection: Axis.horizontal,
                          itemCount: group[0].data.length,
                          onPageChanged: (horizontalIndex) {
                            // 가로 스크롤 시 Provider에 선택된 텍스트 전달
                            String currentText = group[0].data[horizontalIndex];
                            Provider.of<StatusProvider>(context, listen: false)
                                .setCurrentText(currentText);
                          },
                          itemBuilder: (context, horizontalIndex) {
                            WorkplaceData workplaceData = group[0];
                            return Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: workplaceData.color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  workplaceData.data[horizontalIndex],
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ),

          // 소지금 표시 부분
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '₩ 900,000',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
