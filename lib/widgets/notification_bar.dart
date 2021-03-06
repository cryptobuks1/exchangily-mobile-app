/*
* Copyright (c) 2020 Exchangily LLC
*
* Licensed under Apache License v2.0
* You may obtain a copy of the License at
*
*      https://www.apache.org/licenses/LICENSE-2.0
*
*----------------------------------------------------------------------
* Author: barry-ruprai@exchangily.com
*----------------------------------------------------------------------
*/

import 'package:flushbar/flushbar.dart';
import 'package:flutter/cupertino.dart';
import '../shared/globals.dart' as globals;

class NotificationBar extends StatefulWidget {
  final String title;
  final String message;
  final IconData iconData;
  final Color leftBarColor;
  const NotificationBar(
      {Key key, this.title, this.message, this.iconData, this.leftBarColor})
      : super(key: key);

  @override
  _NotificationBar createState() => _NotificationBar();
}

class _NotificationBar extends State<NotificationBar> {
  @override
  Widget build(BuildContext context) {
    Flushbar(
      backgroundColor: globals.secondaryColor.withOpacity(0.75),
      title: widget.title,
      message: widget.message,
      icon: Icon(
        widget.iconData,
        size: 24,
        color: globals.primaryColor,
      ),
      leftBarIndicatorColor: widget.leftBarColor,
      duration: Duration(seconds: 3),
    ).show(context);
  }
}
