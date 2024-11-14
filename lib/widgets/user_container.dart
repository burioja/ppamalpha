// lib/widgets/user_container.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/status_provider.dart';
import 'user_status_widget.dart';
import 'package:geocoding/geocoding.dart'; // geocoding 패키지 추가

class UserContainer extends StatefulWidget {
  const UserContainer({super.key});

  @override
  _UserContainerState createState() => _UserContainerState();
}

class _UserContainerState extends State<UserContainer> {
  String _currentLocation = '위치 불러오는 중...';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _currentLocation = '위치 서비스 비활성화';
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _currentLocation = '위치 권한 거부됨';
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _currentLocation = '위치 권한이 영구적으로 거부됨';
        });
      }
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    try {
      // localeIdentifier 파라미터 제거
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        if (mounted) {
          setState(() {
            _currentLocation = "${place.subLocality}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = '주소 변환 오류';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 위치 표시 부분
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: Colors.white),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown, // 텍스트 크기를 박스 크기에 맞게 조정
                    child: Text(
                      _currentLocation,
                      textAlign: TextAlign.center,  // 중앙 정렬
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis, // 너무 길 경우 말줄임표
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 상태 컨테이너
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
