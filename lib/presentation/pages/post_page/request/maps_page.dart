import 'dart:async';

import 'package:capston/data/providers/dataonmap_provider.dart';
import 'package:capston/presentation/utils/constant/colors.dart';
import 'package:capston/presentation/widgets/appbar_widget.dart';
import 'package:capston/presentation/widgets/button_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/text_widget.dart';

class MapSample extends StatefulWidget {
  @override
  State<MapSample> createState() => MapSampleState();
}

late double lat;
late double long;

class MapSampleState extends State<MapSample> {
  @override
  void initState() {
    super.initState();
    addMarker();
    addMarker1();
    addPolyline();
    _determinePosition();
    getLocation();
    getData();
  }

  bool isClicked = false;

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  bool hasLoaded = false;

  final Completer<GoogleMapController> _controller = Completer();

  getLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      lat = position.latitude;
      long = position.longitude;
      hasLoaded = true;
    });
  }

  static final CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(lat, long),
    zoom: 18,
  );

  final Set<Marker> _marker = <Marker>{};

  addMarker() {
    var sourcePosition = LatLng(context.read<MapDataProvider>().getMyLat,
        context.read<MapDataProvider>().getMyLong);
    _marker.add(Marker(
      infoWindow: const InfoWindow(
        title: 'Your Location',
      ),
      markerId: const MarkerId('myPosition'),
      icon: BitmapDescriptor.defaultMarker,
      position: sourcePosition,
    ));
  }

  addMarker1() {
    var sourcePosition = LatLng(context.read<MapDataProvider>().getLat,
        context.read<MapDataProvider>().getLong);
    _marker.add(Marker(
      infoWindow: const InfoWindow(
        title: 'Customer Location',
      ),
      markerId: const MarkerId('destinationLocation'),
      icon: BitmapDescriptor.defaultMarker,
      position: sourcePosition,
    ));
  }

  late Polyline _poly;

  addPolyline() {
    _poly = Polyline(
        color: Colors.red,
        polylineId: const PolylineId('lans'),
        points: [
          // User Location
          LatLng(context.read<MapDataProvider>().getMyLat,
              context.read<MapDataProvider>().getMyLong),
          LatLng(context.read<MapDataProvider>().getLat,
              context.read<MapDataProvider>().getLong),
        ],
        width: 4);
  }

  final box = GetStorage();

  late String request = '';

  getData() async {
    var collection = FirebaseFirestore.instance
        .collection('Booking')
        .where('id', isEqualTo: context.read<MapDataProvider>().getId);

    var querySnapshot = await collection.get();
    if (mounted) {
      setState(() {
        for (var queryDocumentSnapshot in querySnapshot.docs) {
          Map<String, dynamic> data = queryDocumentSnapshot.data();
          request = data['request'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppbarWidget('Map'),
        body: hasLoaded
            ? Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    markers: _marker,
                    polylines: {_poly},
                    zoomControlsEnabled: false,
                    initialCameraPosition: _kGooglePlex,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      request != 'Accepted'
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: MaterialButton(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  color: appBarColor,
                                  onPressed: () async {
                                    // Delete document to Firestore
                                    FirebaseFirestore.instance
                                        .collection('Booking')
                                        .doc(context
                                            .read<MapDataProvider>()
                                            .getId)
                                        .update({'request': 'Accepted'});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Customer Request Accepted'),
                                      ),
                                    );
                                    getData();
                                    Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                            builder: (context) => MapSample()));
                                  },
                                  child: const Padding(
                                    padding:
                                        EdgeInsets.fromLTRB(80, 15, 80, 15),
                                    child: TextRegular(
                                        text: 'Accept Request',
                                        color: Colors.white,
                                        fontSize: 14),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: ExpansionTile(
                            leading: const Icon(Icons.person),
                            collapsedIconColor: Colors.black,
                            title: const TextBold(
                                text: 'View Customer',
                                color: Colors.black,
                                fontSize: 18),
                            children: [
                              CircleAvatar(
                                minRadius: 40,
                                maxRadius: 40,
                                backgroundImage: NetworkImage(context
                                    .read<MapDataProvider>()
                                    .getUserProfilePicture),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              TextBold(
                                  text: context
                                      .read<MapDataProvider>()
                                      .getRequesterName,
                                  color: Colors.black,
                                  fontSize: 24),
                              TextRegular(
                                  text: context
                                      .read<MapDataProvider>()
                                      .getContactNumber,
                                  color: Colors.grey,
                                  fontSize: 12),
                              const SizedBox(
                                height: 10,
                              ),
                              ButtonWidget(
                                text: 'Call Me',
                                onPressed: () async {
                                  String driverContactNumber = context
                                      .read<MapDataProvider>()
                                      .getContactNumber;
                                  final _text = 'tel:$driverContactNumber';
                                  if (await canLaunch(_text)) {
                                    await launch(_text);
                                  }
                                },
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(
                color: Colors.black,
              )));
  }
}



// Padding(
//                               padding: const EdgeInsets.only(bottom: 10),
//                               child: Align(
//                                 alignment: Alignment.bottomCenter,
//                                 child: MaterialButton(
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                   ),
//                                   color: appBarColor,
//                                   onPressed: () async {
//                                     // Delete document to Firestore
//                                     FirebaseFirestore.instance
//                                         .collection('Booking')
//                                         .doc(context
//                                             .read<MapDataProvider>()
//                                             .getId)
//                                         .delete();
//                                     Navigator.of(context).pushReplacement(
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                                 ResquestPage()));
//                                   },
//                                   child: const Padding(
//                                     padding:
//                                         EdgeInsets.fromLTRB(80, 15, 80, 15),
//                                     child: TextRegular(
//                                         text: 'Done Servicing',
//                                         color: Colors.white,
//                                         fontSize: 14),
//                                   ),
//                                 ),
//                               ),
//                             ),
