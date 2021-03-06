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

import 'package:exchangilymobileapp/localizations.dart';
import 'package:exchangilymobileapp/services/db/wallet_database_service.dart';
import 'package:exchangilymobileapp/services/shared_service.dart';
import 'package:flutter/material.dart';
import 'package:exchangilymobileapp/enums/screen_state.dart';
import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/models/wallet.dart';
import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/wallet_service.dart';
import 'package:exchangilymobileapp/screen_state/base_state.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class WalletDashboardScreenState extends BaseState {
  final log = getLogger('WalletDahsboardScreenState');
  List<WalletInfo> walletInfo;
  WalletService walletService = locator<WalletService>();
  SharedService sharedService = locator<SharedService>();
  WalletDataBaseService databaseService = locator<WalletDataBaseService>();
  final double elevation = 5;
  double totalUsdBalance = 0;
  double coinUsdBalance;
  double gasAmount = 0;
  String exgAddress = '';
  String wallets;
  List walletInfoCopy = [];
  BuildContext context;
  bool isHideSmallAmountAssets = false;
  RefreshController refreshController =
      RefreshController(initialRefresh: false);

  // Pull to refresh
  void onRefresh() async {
    await refreshBalance();
    refreshController.refreshCompleted();
  }

// Hide Small Amount Assets

  hideSmallAmountAssets() {
    setState(ViewState.Busy);
    isHideSmallAmountAssets = !isHideSmallAmountAssets;
    setState(ViewState.Idle);
  }

// Calculate Total Usd Balance of Coins
  calcTotalBal(numberOfCoins) {
    totalUsdBalance = 0;
    for (var i = 0; i < numberOfCoins; i++) {
      totalUsdBalance = totalUsdBalance + walletInfo[i].usdValue;
    }
    setState(ViewState.Idle);
  }

  getGas() async {
    setState(ViewState.Busy);
    for (var i = 0; i < walletInfo.length; i++) {
      String tName = walletInfo[i].tickerName;
      if (tName == 'EXG') {
        exgAddress = walletInfo[i].address;
        await walletService
            .gasBalance(exgAddress)
            .then((data) => gasAmount = data)
            .catchError((onError) => log.e(onError));
        setState(ViewState.Idle);
        return gasAmount;
      }
    }
    setState(ViewState.Idle);
  }

  // Retrive Wallets Object From Storage

  retrieveWallets() async {
    setState(ViewState.Busy);
    await databaseService.getAll().then((res) {
      walletInfo = res;
      calcTotalBal(walletInfo.length);
      walletInfoCopy = walletInfo.map((element) => element).toList();
      setState(ViewState.Idle);
    }).catchError((error) {
      log.e('Catch Error $error');
      setState(ViewState.Idle);
    });
  }

  Future refreshBalance() async {
    setState(ViewState.Busy);
    // Make a copy of walletInfo as after refresh its count doubled so this way we seperate the UI walletinfo from state
    // also copy wallet keep the previous balance when loading shows shimmers instead of blank screen or zero bal
    walletInfoCopy = walletInfo.map((element) => element).toList();
    int length = walletInfoCopy.length;
    List<String> coinTokenType = walletService.tokenType;
    walletInfo.clear();
    double walletBal = 0;
    double walletLockedBal = 0;
    for (var i = 0; i < length; i++) {
      int id = i + 1;
      String tickerName = walletInfoCopy[i].tickerName;
      String address = walletInfoCopy[i].address;
      String name = walletInfoCopy[i].name;
      await walletService
          .coinBalanceByAddress(tickerName, address, coinTokenType[i])
          .then((balance) async {
        walletBal = balance['balance'];
        walletLockedBal = balance['lockbalance'];
      }).timeout(Duration(seconds: 25), onTimeout: () async {
        setState(ViewState.Idle);
        walletService.showInfoFlushbar(
            'Timeout',
            AppLocalizations.of(context).serverTimeoutPleaseTryAgainLater,
            Icons.cancel,
            Colors.red,
            context);
        await retrieveWallets();
        log.e('Timeout');
      }).catchError((error) async {
        setState(ViewState.Idle);
        await retrieveWallets();
        log.e('Something went wrong  - $error');
      });
      double marketPrice = await walletService.getCoinMarketPrice(name);
      coinUsdBalance = walletService.calculateCoinUsdBalance(
          marketPrice, walletBal, walletLockedBal);
      WalletInfo wi = WalletInfo(
          id: id,
          tickerName: tickerName,
          tokenType: coinTokenType[i],
          address: address,
          availableBalance: walletBal,
          lockedBalance: walletLockedBal,
          usdValue: coinUsdBalance,
          name: name);
      walletInfo.add(wi);
    } // For loop ends
    calcTotalBal(length);
    await getGas();
    await getExchangeAssets();
    await updateWalletDatabase();
    setState(ViewState.Idle);
    return walletInfo;
  }

  // Update wallet database
  updateWalletDatabase() async {
    log.w('test t4estdsfasdgfasg ');
    for (int i = 0; i < walletInfo.length; i++) {
      await databaseService.update(walletInfo[i]);
      await databaseService.getById(walletInfo[i].id);
    }
  }

  // Get Exchange Assets

  getExchangeAssets() async {
    setState(ViewState.Busy);
    log.e(exgAddress);
    var res = await walletService.assetsBalance(exgAddress);
    log.e(res);
    var length = res.length;
    for (var i = 0; i < length; i++) {
      // Get their tickerName to compare with walletInfo tickernName
      String coin = res[i]['coin'];
      // Second For loop to check walletInfo tickerName according to its length and
      // compare it with the same coin tickername from service until the match or loop ends
      for (var j = 0; j < walletInfo.length; j++) {
        if (coin == walletInfo[j].tickerName) {
          log.e('$coin - $walletInfo[j].tickerName');
          walletInfo[j].inExchange = res[i]['amount'];
          log.w(walletInfo[j].inExchange);
          break;
        }
      }
    }
    walletInfoCopy = walletInfo.map((element) => element).toList();
    setState(ViewState.Idle);
  }

  onBackButtonPressed() async {
    sharedService.context = context;
    await sharedService.closeApp();
  }
}
