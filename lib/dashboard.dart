// ignore_for_file: sort_child_properties_last, prefer_const_literals_to_create_immutables, prefer_const_constructors, avoid_print, use_key_in_widget_constructors, use_build_context_synchronously, unnecessary_new

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mq4_mq7_gas_detector/global_var.dart' as globals;
import 'dart:async';
import 'notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class Dashboard extends StatefulWidget {
  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  List<TextEditingController> _data = [TextEditingController()];
  bool status = false;
  Timer? timer;
  double Metana = 0;
  double CO = 0;

  void initState() {
    super.initState();
    getEndpoint();
    notif.initialize(flutterLocalNotificationsPlugin);
    timer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => updateValue());
  }

  void getEndpoint() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? endpoint = prefs.getString('endpoint');
    if (endpoint != null) {
      setState(() {
        _data[0].text = endpoint;
        globals.endpoint = endpoint;
      });
    } else {
      _data[0].text = "0.0.0.0";
      globals.endpoint = "0.0.0.0";
    }
  }

  void updateValue() async {
    var url = Uri.parse("http://${globals.endpoint}/getValue");
    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          // Time has run out, do what you wanted to do.
          return http.Response(
              'Error', 408); // Request Timeout response status code
        },
      );
      print(response.statusCode);
      // context.loaderOverlay.hide();
      if (response.statusCode == 200) {
        var respon = Json.tryDecode(response.body);
        if (this.mounted) {
          setState(() {
            Metana = respon['mq4']['value'];
            CO = respon['mq7']['value'];
          });
        }
        if (respon['mq4']['notif']['show']) {
          notif.showNotif(
              id: respon['mq4']['notif']['id'],
              head: respon['mq4']['notif']['header'],
              body: respon['mq4']['notif']['body'],
              fln: flutterLocalNotificationsPlugin);
          await http.post(
            Uri.parse("http://${globals.endpoint}/updateNotif"),
            headers: <String, String>{
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: "sensor=MQ4",
          );
        }
        if (respon['mq7']['notif']['show']) {
          notif.showNotif(
              id: respon['mq7']['notif']['id'],
              head: respon['mq7']['notif']['header'],
              body: respon['mq7']['notif']['body'],
              fln: flutterLocalNotificationsPlugin);
          await http.post(
            Uri.parse("http://${globals.endpoint}/updateNotif"),
            headers: <String, String>{
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: "sensor=MQ7",
          );
        }
      }
    } on Exception catch (_) {
      // rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        timer?.cancel();
        // Navigator.pop(context);
        return Future.value(false);
      },
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: Color.fromARGB(255, 0, 44, 138),
            // leading: IconButton(
            //   icon: Icon(Icons.arrow_back),
            //   onPressed: () => Phoenix.rebirth(context),
            // ),
            title: Text(
              "CH₄ & CO Monitoring",
              style: TextStyle(color: Colors.white),
            ),
            actions: <Widget>[
              IconButton(
                  icon: const Icon(Icons.settings,
                      color: Colors.white, size: 20.0),
                  onPressed: () async {
                    //================================ ALERT UNTUK SETTING API ========================================
                    Alert(
                      context: context,
                      // type: AlertType.info,
                      desc: "Setting API",
                      content: Column(
                        children: <Widget>[
                          SizedBox(
                              height: MediaQuery.of(context).size.width / 15),
                          TextField(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'IP Endpoint',
                              labelStyle: TextStyle(fontSize: 20),
                            ),
                            controller: _data[0],
                          ),
                        ],
                      ),
                      buttons: [
                        DialogButton(
                            child: Text(
                              "Save",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            onPressed: () async {
                              if (_data[0].text.isEmpty) {
                                status = false;
                                Alert(
                                  context: context,
                                  type: AlertType.error,
                                  title: "Value Cannot be Empty!",
                                  buttons: [
                                    DialogButton(
                                      child: Text(
                                        "OK",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 20),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    )
                                  ],
                                ).show();
                              } else {
                                var url = Uri.parse('http://' +
                                    _data[0].text +
                                    '/getValue');
                                try {
                                  final response = await http.get(url).timeout(
                                    const Duration(
                                        seconds: globals.httpTimeout),
                                    onTimeout: () {
                                      // Time has run out, do what you wanted to do.
                                      return http.Response('Error',
                                          408); // Request Timeout response status code
                                    },
                                  );
                                  // context.loaderOverlay.hide();
                                  if (response.statusCode == 200) {
                                    Alert(
                                      context: context,
                                      type: AlertType.success,
                                      title: "Connection OK",
                                      buttons: [
                                        DialogButton(
                                            child: Text(
                                              "OK",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20),
                                            ),
                                            onPressed: () async {
                                              final SharedPreferences prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              setState(() {
                                                globals.endpoint =
                                                    _data[0].text;
                                                prefs.setString(
                                                    "endpoint", _data[0].text);
                                              });
                                              Navigator.pop(context);
                                              Navigator.pop(context);
                                            })
                                      ],
                                    ).show();
                                  } else {
                                    Alert(
                                      context: context,
                                      type: AlertType.error,
                                      title: "Connection Failed!",
                                      desc: "Please check Endpoint IP",
                                      buttons: [
                                        DialogButton(
                                          child: Text(
                                            "OK",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        )
                                      ],
                                    ).show();
                                  }
                                } on Exception catch (_) {
                                  Alert(
                                    context: context,
                                    type: AlertType.error,
                                    title: "Connection Failed!",
                                    desc: "Please check Endpoint IP",
                                    buttons: [
                                      DialogButton(
                                        child: Text(
                                          "OK",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20),
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ).show();
                                  // rethrow;
                                }
                              }
                            }),
                      ],
                    ).show();

                    //================================ END ALERT UNTUK SETTING API ========================================
                  })
            ],
          ),
          body: StaggeredGridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: <Widget>[
            // Container(
            //   padding: EdgeInsets.all(5),
            //   child: 
            //     Row(
            //       children: [
            //         Container(
            //           padding: EdgeInsets.all(5),
            //           child: TextField(
            //                   decoration: InputDecoration(
            //                     border: OutlineInputBorder(),
            //                     labelText: 'IP Endpoint',
            //                     labelStyle: TextStyle(fontSize: 20),
            //                   ),
            //                   controller: _data[0],
            //                 )),
            //         Container(
            //           padding: EdgeInsets.all(5),
            //           child: ElevatedButton(onPressed: (){}, child: Text("Save"))
            //         ),
            //       ]
            //     )
            //   ),
              myCard2("Metana (CH₄)", 'Metana adalah hidrokarbon paling sederhana yang berbentuk gas dengan rumus kimia CH4. Metana murni tidak berbau, tetapi jika digunakan untuk keperluan komersial, biasanya ditambahkan sedikit bau belerang untuk mendeteksi kebocoran yang mungkin terjadi',
                  Icon(Icons.gas_meter, color: Colors.white, size: 30.0)),
              myCard("Sensor Metana (CH₄)", Metana.toString() + ' ppm',
                  Icon(Icons.gas_meter, color: Colors.white, size: 30.0)),
              myCard2("Carbon Monoxide (CO)", 'Karbon monoksida, rumus kimia CO, adalah gas yang tak berwarna, tak berbau, dan tak berasa. Ia terdiri dari satu atom karbon yang secara kovalen berikatan dengan satu atom oksigen. Dalam ikatan ini, terdapat dua ikatan kovalen dan satu ikatan kovalen koordinasi antara atom karbon dan oksigen.',
                  Icon(Icons.gas_meter, color: Colors.white, size: 30.0)),
              myCard("Sensor Carbon Monoxide (CO)", CO.toString() + ' ppm',
                  Icon(Icons.gas_meter, color: Colors.white, size: 30.0)),
            ],
            staggeredTiles: [
              StaggeredTile.extent(2, 180.0),
              StaggeredTile.extent(2, 110.0),
              StaggeredTile.extent(2, 200.0),
              StaggeredTile.extent(2, 110.0),
            ],
          )),
    );
  }

  Widget _buildTile(Widget child, {Function()? onTap}) {
    return Material(
        elevation: 14.0,
        borderRadius: BorderRadius.circular(12.0),
        shadowColor: Color(0x802196F3),
        child: InkWell(
            // Do onTap() if it isn't null, otherwise do print()
            onTap: onTap != null
                ? () => onTap()
                : () {
                    print('Not set yet');
                  },
            child: child));
  }

  Widget myCard(String title, String value, Widget icon) {
    return _buildTile(
      Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                Text(title, style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                  Text(value,
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 28.0))
                ],
              ),
              Material(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(24.0),
                  child: Center(
                      child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: icon,
                  )))
            ]),
      ),
    );
  }
  Widget myCard2(String title, String value, Widget icon) {
    return _buildTile(
      Padding(
        padding: const EdgeInsets.all(24.0),
        child: 
         Expanded(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: new Text(value),
                ),
              ],
            ),
         )
        
        
        
        
        
        
        
        
        // Row(
        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //     crossAxisAlignment: CrossAxisAlignment.center,
        //     children: <Widget>[
        //       Column(
        //         mainAxisAlignment: MainAxisAlignment.center,
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: <Widget>[
        //           Text(title, style: TextStyle(color: Colors.blueAccent)),
        //           Text(value,
        //               style: TextStyle(
        //                   color: Colors.black,
        //                   // fontWeight: FontWeight.w500,
        //                   fontSize: 14.0))
        //         ],
        //       ),
        //       Material(
        //           color: Colors.blue,
        //           borderRadius: BorderRadius.circular(24.0),
        //           child: Center(
        //               child: Padding(
        //             padding: const EdgeInsets.all(16.0),
        //             child: icon,
        //           )))
        //     ]),
      ),
    );
  }
}

class Json {
  static String? tryEncode(data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      return null;
    }
  }

  static dynamic tryDecode(data) {
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }
}
