/*
* Copyright (c) 2020 Exchangily LLC
*
* Licensed under Apache License v2.0
* You may obtain a copy of the License at
*
*      https://www.apache.org/licenses/LICENSE-2.0
*
*----------------------------------------------------------------------
* Author: ken.qiu@exchangily.com
*----------------------------------------------------------------------
*/

import 'package:exchangilymobileapp/enums/screen_state.dart';
import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/screens/base_screen.dart';
import 'package:exchangilymobileapp/shared/ui_helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/globals.dart' as globals;
import '../../../models/wallet.dart';
import 'package:exchangilymobileapp/models/wallet.dart';
import 'package:flutter/gestures.dart';
import 'package:exchangilymobileapp/screen_state/wallet/wallet_features/deposit_screen_state.dart';

// {"success":true,"data":{"transactionID":"7f9d1b3fad00afa85076d28d46fd3457f66300989086b95c73ed84e9b3906de8"}}
class Deposit extends StatefulWidget {
  final WalletInfo walletInfo;

  Deposit({Key key, this.walletInfo}) : super(key: key);

  @override
  _DepositState createState() => _DepositState();
}

class _DepositState extends State<Deposit> {
  @override
  Widget build(BuildContext context) {
    double bal = widget.walletInfo.availableBalance;
    String coinName = widget.walletInfo.tickerName;

    return BaseScreen<DepositScreenState>(
      onModelReady: (model) {
        model.context = context;
        model.walletInfo = widget.walletInfo;
        model.initState();
      },
      builder: (context, model, child) => Scaffold(
        appBar: CupertinoNavigationBar(
          padding: EdgeInsetsDirectional.only(start: 0),
          leading: CupertinoButton(
            padding: EdgeInsets.all(0),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          middle: Text(
            '${AppLocalizations.of(context).move}  ${widget.walletInfo.tickerName}  ${AppLocalizations.of(context).toExchange}',
            style: Theme.of(context).textTheme.headline3,
          ),
          backgroundColor: Color(0XFF1f2233),
        ),
        backgroundColor: Color(0xFF1F2233),
        body: Container(
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: ListView(
            children: <Widget>[
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (String amount) {
                  model.updateTransFee();
                },
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0XFF871fff), width: 1.0)),
                  hintText: AppLocalizations.of(context).enterAmount,
                  hintStyle: TextStyle(fontSize: 14.0, color: Colors.grey),
                ),
                controller: model.myController,
                style: Theme.of(context)
                    .textTheme
                    .headline5
                    .copyWith(fontWeight: FontWeight.w300),
              ),
              Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(AppLocalizations.of(context).gasFee,
                            style: Theme.of(context)
                                .textTheme
                                .headline5
                                .copyWith(fontWeight: FontWeight.w300)),
                        Padding(
                          padding: EdgeInsets.only(
                              left:
                                  5), // padding left to keep some space from the text
                          child: Text('${model.transFee}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headline5
                                  .copyWith(fontWeight: FontWeight.w300)),
                        )
                      ],
                    ),
                    UIHelper.horizontalSpaceSmall,
                    // Kanaban Gas Fee Row
                    Row(
                      children: <Widget>[
                        Text(AppLocalizations.of(context).kanbanGasFee,
                            style: Theme.of(context)
                                .textTheme
                                .headline5
                                .copyWith(fontWeight: FontWeight.w300)),
                        Padding(
                          padding: EdgeInsets.only(
                              left:
                                  5), // padding left to keep some space from the text
                          child: Text('${model.kanbanTransFee}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headline5
                                  .copyWith(fontWeight: FontWeight.w300)),
                        )
                      ],
                    ),
                    // Switch Row
                    Row(
                      children: <Widget>[
                        Text(AppLocalizations.of(context).advance,
                            style: Theme.of(context)
                                .textTheme
                                .headline5
                                .copyWith(fontWeight: FontWeight.w300)),
                        Switch(
                          value: model.transFeeAdvance,
                          inactiveTrackColor: globals.grey,
                          dragStartBehavior: DragStartBehavior.start,
                          activeColor: globals.primaryColor,
                          onChanged: (bool isOn) {
                            setState(() {
                              model.transFeeAdvance = isOn;
                            });
                          },
                        )
                      ],
                    ),
                    // Transaction Fee Advance
                    Visibility(
                        visible: model.transFeeAdvance,
                        child: Column(
                          children: <Widget>[
                            Visibility(
                                visible: (coinName == 'ETH' ||
                                    model.tokenType == 'ETH' ||
                                    model.tokenType == 'FAB'),
                                child: Row(
                                  children: <Widget>[
                                    Text(AppLocalizations.of(context).gasPrice,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline5
                                            .copyWith(
                                                fontWeight: FontWeight.w300)),
                                    Expanded(
                                        child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                85, 0, 0, 0),
                                            child: TextField(
                                                controller: model
                                                    .gasPriceTextController,
                                                onChanged: (String amount) {
                                                  model.updateTransFee();
                                                },
                                                keyboardType: TextInputType
                                                    .number, // numnber keyboard
                                                decoration: InputDecoration(
                                                    focusedBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: globals
                                                                .primaryColor)),
                                                    enabledBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color:
                                                                globals.grey)),
                                                    hintText: '0.00000',
                                                    hintStyle: Theme.of(context)
                                                        .textTheme
                                                        .headline5
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w300)),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(
                                                        fontWeight: FontWeight.w300))))
                                  ],
                                )),
                            Visibility(
                                visible: (coinName == 'ETH' ||
                                    model.tokenType == 'ETH' ||
                                    model.tokenType == 'FAB'),
                                child: Row(
                                  children: <Widget>[
                                    Text(AppLocalizations.of(context).gasLimit,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline5
                                            .copyWith(
                                                fontWeight: FontWeight.w300)),
                                    Expanded(
                                        child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                85, 0, 0, 0),
                                            child: TextField(
                                                controller: model
                                                    .gasLimitTextController,
                                                onChanged: (String amount) {
                                                  model.updateTransFee();
                                                },
                                                keyboardType: TextInputType
                                                    .number, // numnber keyboard
                                                decoration: InputDecoration(
                                                    focusedBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: globals
                                                                .primaryColor)),
                                                    enabledBorder: UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color:
                                                                globals.grey)),
                                                    hintText: '0.00000',
                                                    hintStyle: Theme.of(context)
                                                        .textTheme
                                                        .headline5
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w300)),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(
                                                        fontWeight: FontWeight.w300))))
                                  ],
                                )),
                            Visibility(
                                visible: (coinName == 'BTC' ||
                                    coinName == 'FAB' ||
                                    model.tokenType == 'FAB'),
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                        AppLocalizations.of(context)
                                            .satoshisPerByte,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline5
                                            .copyWith(
                                                fontWeight: FontWeight.w300)),
                                    Expanded(
                                        child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                50, 0, 0, 0),
                                            child: TextField(
                                              controller: model
                                                  .satoshisPerByteTextController,
                                              onChanged: (String amount) {
                                                model.updateTransFee();
                                              },
                                              keyboardType: TextInputType
                                                  .number, // numnber keyboard
                                              decoration: InputDecoration(
                                                  focusedBorder:
                                                      UnderlineInputBorder(
                                                          borderSide: BorderSide(
                                                              color: globals
                                                                  .primaryColor)),
                                                  enabledBorder:
                                                      UnderlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                                  color: globals
                                                                      .grey)),
                                                  hintText: '0.00000',
                                                  hintStyle: Theme.of(context)
                                                      .textTheme
                                                      .headline5
                                                      .copyWith(
                                                          fontWeight:
                                                              FontWeight.w300)),
                                              style: TextStyle(
                                                  color: globals.grey,
                                                  fontSize: 16),
                                            )))
                                  ],
                                )),
                            Row(
                              children: <Widget>[
                                Text(
                                    AppLocalizations.of(context).kanbanGasPrice,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline5
                                        .copyWith(fontWeight: FontWeight.w300)),
                                Expanded(
                                    child: Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(20, 0, 0, 0),
                                        child: TextField(
                                            controller: model
                                                .kanbanGasPriceTextController,
                                            onChanged: (String amount) {
                                              model.updateTransFee();
                                            },
                                            keyboardType: TextInputType
                                                .number, // numnber keyboard
                                            decoration: InputDecoration(
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: globals
                                                                .primaryColor)),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color:
                                                                globals.grey)),
                                                hintText: '0.00000',
                                                hintStyle: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w300)),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.w300))))
                              ],
                            ),
                            Row(
                              children: <Widget>[
                                Text(
                                    AppLocalizations.of(context).kanbanGasLimit,
                                    style:
                                        Theme.of(context).textTheme.headline5),
                                Expanded(
                                    child: Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(20, 0, 0, 0),
                                        child: TextField(
                                          controller: model
                                              .kanbanGasLimitTextController,
                                          onChanged: (String amount) {
                                            model.updateTransFee();
                                          },
                                          keyboardType: TextInputType
                                              .number, // numnber keyboard
                                          decoration: InputDecoration(
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: globals
                                                              .primaryColor)),
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: globals.grey)),
                                              hintText: '0.00000',
                                              hintStyle: Theme.of(context)
                                                  .textTheme
                                                  .headline5
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w300)),
                                          style: TextStyle(
                                              color: globals.grey,
                                              fontSize: 16),
                                        )))
                              ],
                            )
                          ],
                        ))
                  ],
                ),
              ),

              // Wallet Balance
              Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 5.0),
                    child: Text(
                        AppLocalizations.of(context).walletbalance + '  $bal',
                        style: Theme.of(context).textTheme.bodyText2),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child: Text('$coinName'.toUpperCase(),
                        style: Theme.of(context).textTheme.bodyText2),
                  )
                ],
              ),
              UIHelper.horizontalSpaceSmall,
              // Confirm Button
              MaterialButton(
                padding: EdgeInsets.all(15),
                color: globals.primaryColor,
                textColor: Colors.white,
                onPressed: () {
                  //var res = await new WalletService().depositDo('ETH', '', double.parse(myController.text));
                  // var res = await new WalletService().depositDo('USDT', 'ETH', double.parse(myController.text));
                  // var res = await new WalletService().depositDo('FAB', '', double.parse(myController.text));
                  //var res = await new WalletService().depositDo('EXG', 'FAB', double.parse(myController.text));
                  // var res = await new WalletService().depositDo('BTC', '', double.parse(myController.text));
                  //print('res from await depositDo=');
                  //print(res);
                  // double amount = double.parse(model.myController.text);

                  model.checkPass();
                },
                child: model.state == ViewState.Busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 1,))
                    : Text(AppLocalizations.of(context).confirm,
                        style: Theme.of(context).textTheme.headline4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
