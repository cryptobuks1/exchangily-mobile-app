import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/api_service.dart';
import 'package:exchangilymobileapp/services/db/wallet_database_service.dart';
import 'package:exchangilymobileapp/utils/btc_util.dart';
import 'package:exchangilymobileapp/utils/fab_util.dart';
import 'package:flushbar/flushbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:bip39/bip39.dart' as bip39;
import '../packages/bip32/bip32_base.dart' as bip32;
import 'package:hex/hex.dart';
import "package:pointycastle/pointycastle.dart";
import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../shared/globals.dart' as globals;
import '../environments/coins.dart' as coinList;
import '../utils/abi_util.dart';
import '../utils/string_util.dart' as stringUtils;
import '../utils/kanban.util.dart';
import '../utils/keypair_util.dart';
import '../utils/eth_util.dart';
import '../utils/fab_util.dart';
import '../utils/coin_util.dart';
import '../models/wallet.dart';
import 'dart:io';
import 'dart:convert';
import 'package:bitcoin_flutter/src/models/networks.dart';
import 'package:bitcoin_flutter/src/payments/p2pkh.dart';
import 'package:bitcoin_flutter/src/transaction_builder.dart';
import 'package:bitcoin_flutter/src/transaction.dart' as btcTransaction;
import 'package:bitcoin_flutter/src/ecpair.dart';
import 'package:bitcoin_flutter/src/utils/script.dart' as script;
import '../environments/environment.dart';
import 'package:bitcoin_flutter/src/bitcoin_flutter_base.dart';
import 'package:web_socket_channel/io.dart';
import 'package:encrypt/encrypt.dart' as prefix0;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:decimal/decimal.dart';

class WalletService {
  final log = getLogger('Wallet Service');
  Api _api = locator<Api>();

  WalletDataBaseService databaseService = locator<WalletDataBaseService>();
  double coinUsdBalance;
  List<String> coinTickers = ['BTC', 'ETH', 'FAB', 'USDT', 'EXG'];
  List<String> tokenType = ['', '', '', 'ETH', 'FAB'];

  List<String> coinNames = [
    'bitcoin',
    'ethereum',
    'fabcoin',
    'tether',
    'exchangily'
  ];

  // Get Random Mnemonic
  String getRandomMnemonic() {
    String randomMnemonic = '';
    if (isLocal == true) {
      randomMnemonic =
          'culture sound obey clean pretty medal churn behind chief cactus alley ready';
      return randomMnemonic;
    }
    randomMnemonic = bip39.generateMnemonic();
    return randomMnemonic;
  }

  // Save Encrypted Data to Storage
  saveEncryptedData(String data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/my_file.byte');
      await deleteEncryptedData();
      await file.writeAsString(data);
      log.w('Encrypted data saved in storage');
    } catch (e) {
      log.e("Couldn't write encrypted datra to file!! $e");
    }
  }

  // Delete Encrypted Data
  deleteEncryptedData() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/my_file.byte');
    await file
        .delete()
        .then((res) => log.w('Previous data in the stored file deleted $res'))
        .catchError((error) => log.e('Previous data deletion failed $error'));
  }

  // Read Encrypted Data from Storage
  Future<String> readEncryptedData(String userPass) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/my_file.byte');

      String test = await file.readAsString();
      prefix0.Encrypted encryptedText = prefix0.Encrypted.fromBase64(test);
      final key = prefix0.Key.fromLength(32);
      final iv = prefix0.IV.fromUtf8(userPass);
      final encrypter = prefix0.Encrypter(prefix0.AES(key));
      final decrypted = encrypter.decrypt(encryptedText, iv: iv);
      return Future.value(decrypted);
    } catch (e) {
      log.e("Couldn't read file -$e");
      return Future.value('');
    }
  }

  // Generate Seed

  generateSeed(String mnemonic) {
    Uint8List seed = bip39.mnemonicToSeed(mnemonic);
    log.w(seed);
    return seed;
  }

  Future getCoinAddresses(String mnemonic) async {
    var seed = generateSeed(mnemonic);
    var root = bip32.BIP32.fromSeed(seed);
    for (int i = 0; i < coinTickers.length; i++) {
      var tickerName = coinTickers[i];
      var addr =
          await getAddressForCoin(root, tickerName, tokenType: tokenType[i]);
      log.w('name $tickerName - address $addr');
      return addr;
    }
  }

// Future Get Coin Balance By Address
  Future coinBalanceByAddress(
      String name, String address, String tokenType) async {
    var bal =
        await getCoinBalanceByAddress(name, address, tokenType: tokenType);
    log.w('$name - Coin Balance $bal');
    if (bal['balance'].isNaN) {
      return 0.0;
    }
    return bal;
  }

  // Get Current Market Price For The Coin By Name
  Future<double> getCoinMarketPrice(String name) async {
    double currentUsdValue;
    var usdVal = await _api.getCoinsUsdValue();
    if (name == 'exchangily') {
      return currentUsdValue = 0.2;
    }
    currentUsdValue = usdVal[name]['usd'];
    log.w('USD VAL of $name - $currentUsdValue');
    return currentUsdValue;
  }

  // Offline Wallet Creation

  Future createOfflineWallets(String mnemonic) async {
    List<WalletInfo> _walletInfo = [];
    if (_walletInfo != null) {
      _walletInfo.clear();
    } else {
      _walletInfo = [];
    }
    var seed = generateSeed(mnemonic);
    var root = bip32.BIP32.fromSeed(seed);

    try {
      for (int i = 0; i < coinTickers.length; i++) {
        String tickerName = coinTickers[i];
        String name = coinNames[i];
        String token = tokenType[i];
        String addr =
            await getAddressForCoin(root, tickerName, tokenType: token);
        WalletInfo wi = new WalletInfo(
            tickerName: tickerName,
            tokenType: token,
            address: addr,
            availableBalance: 0.0,
            lockedBalance: 0.0,
            usdValue: 0.0,
            name: name);
        _walletInfo.add(wi);
        await databaseService.insert(_walletInfo[i]);
      }
      return _walletInfo;
    } catch (e) {
      log.e(e);
      _walletInfo = null;
      log.e('Catch GetAll Wallets Failed $e');
      return _walletInfo;
    }
  }

// Future GetWalletCoins
  Future<List<WalletInfo>> getWalletCoins(String mnemonic) async {
    List<WalletInfo> _walletInfo = [];
    List<double> coinUsdMarketPrice = [];
    String exgAddress = '';
    if (_walletInfo != null) {
      _walletInfo.clear();
    } else {
      _walletInfo = [];
    }
    coinUsdMarketPrice.clear();
    var seed = generateSeed(mnemonic);
    var root = bip32.BIP32.fromSeed(seed);
    try {
      for (int i = 0; i < coinTickers.length; i++) {
        String tickerName = coinTickers[i];
        String name = coinNames[i];
        String token = tokenType[i];
        var marketValue = await getCoinMarketPrice(name);
        coinUsdMarketPrice.add(marketValue);
        String addr =
            await getAddressForCoin(root, tickerName, tokenType: token);
        var bal =
            await getCoinBalanceByAddress(tickerName, addr, tokenType: token);
        double walletBal = bal['balance'];
        double walletLockedBal = bal['lockbalance'];
        log.w(
            'tickername $tickerName - address: $addr - balance: $walletBal - Locked balance: $walletLockedBal');
        calculateCoinUsdBalance(
            coinUsdMarketPrice[i], walletBal, walletLockedBal);
        if (tickerName == 'EXG') {
          exgAddress = addr;
          log.e(exgAddress);
        }
        WalletInfo wi = new WalletInfo(
            tickerName: tickerName,
            tokenType: token,
            address: addr,
            availableBalance: walletBal,
            lockedBalance: walletLockedBal,
            usdValue: coinUsdBalance,
            name: name);
        _walletInfo.add(wi);
      }
      var res = await assetsBalance(exgAddress);
      var length = res.length;
      // For loop over asset balance result
      for (var i = 0; i < length; i++) {
        // Get their tickerName to compare with walletInfo tickerName
        String coin = res[i]['coin'];
        // Second For Loop To check WalletInfo TickerName According to its length and
        // compare it with the same coin tickername from asset balance result until the match or loop ends
        for (var j = 0; j < _walletInfo.length; j++) {
          if (coin == _walletInfo[j].tickerName) {
            _walletInfo[j].inExchange = res[i]['amount'];
            break;
          }
        }
      }

      for (int i = 0; i < _walletInfo.length; i++) {
        await databaseService.insert(_walletInfo[i]);
      }
      return _walletInfo;
    } catch (e) {
      log.e(e);
      _walletInfo = null;
      log.e('Catch GetAll Wallets Failed $e');
      return _walletInfo;
    }
  }

  // Gas Balance
  Future<double> gasBalance(String addr) async {
    double gasAmount = 0.0;
    await _api.getGasBalance(addr).then((res) {
      if (res != null &&
          res['balance'] != null &&
          res['balance']['FAB'] != null) {
        var newBal = BigInt.parse(res['balance']['FAB']);
        gasAmount = stringUtils.bigNum2Double(newBal);
      }
    }).timeout(Duration(seconds: 25), onTimeout: () {
      log.e('Timeout');
      gasAmount = 0.0;
    }).catchError((onError) {
      log.w('On error $onError');
      gasAmount = 0.0;
    });
    return gasAmount;
  }

  // Assets Balance
  assetsBalance(String exgAddress) async {
    List<Map<String, dynamic>> bal = [];
    await _api.getAssetsBalance(exgAddress).then((res) {
      for (var i = 0; i < res.length; i++) {
        var tempBal = res[i];
        var coinType = int.parse(tempBal['coinType']);
        var unlockedAmount =
            stringUtils.bigNum2Double(tempBal['unlockedAmount']);
        var lockedAmount = stringUtils.bigNum2Double(tempBal['lockedAmount']);
        var finalBal = {
          'coin': coinList.coin_list[coinType]['name'],
          'amount': unlockedAmount,
          'lockedAmount': lockedAmount
        };
        bal.add(finalBal);
      }
    }).catchError((onError) {
      log.w('On error assetsBalance $onError');
      bal = [];
    });
    return bal;
  }

  /* ---------------------------------------------------
                Flushbar Notification bar
    -------------------------------------------------- */

  void showInfoFlushbar(String title, String message, IconData iconData,
      Color leftBarColor, BuildContext context) {
    Flushbar(
      backgroundColor: globals.secondaryColor.withOpacity(0.75),
      title: title,
      message: message,
      icon: Icon(
        iconData,
        size: 24,
        color: globals.primaryColor,
      ),
      leftBarIndicatorColor: leftBarColor,
      duration: Duration(seconds: 3),
    ).show(context);
  }

  // Calculate Only Usd Balance For Individual Coin
  double calculateCoinUsdBalance(
      double marketPrice, double actualWalletBalance, double lockedBalance) {
    log.w(
        'usdVal =$marketPrice, actualwallet bal $actualWalletBalance, locked wallet bal $lockedBalance');
    if (actualWalletBalance != 0 && marketPrice != null) {
      coinUsdBalance = (marketPrice * actualWalletBalance);
      coinUsdBalance = coinUsdBalance + lockedBalance;
      // totalUsdBalance.add(coinUsdBalance);
      // log.w('Total coin usd balance list $totalUsdBalance');
      return coinUsdBalance;
    } else {
      coinUsdBalance = 0.0;
      log.i('calculateCoinUsdBalance - Wallet balance 0');
    }
    return coinUsdBalance;
  }

// Add Gas
  Future<int> addGas() async {
    return 0;
  }

// Get Coin Type Id By Name

  getCoinTypeIdByName(String coinName) {
    var coins =
        coinList.coin_list.where((coin) => coin['name'] == coinName).toList();
    if (coins != null) {
      return coins[0]['id'];
    }
    return 0;
  }

// Get Original Message

  getOriginalMessage(
      int coinType, String txHash, BigInt amount, String address) {
    var buf = '';
    buf += stringUtils.fixLength(coinType.toString(), 4);
    buf += stringUtils.fixLength(txHash, 64);
    var hexString = amount.toRadixString(16);
    buf += stringUtils.fixLength(hexString, 64);
    buf += stringUtils.fixLength(address, 64);

    return buf;
  }

  Future<Map<String, dynamic>> withdrawDo(
      seed,
      String coinName,
      String coinAddress,
      String tokenType,
      double amount,
      kanbanPrice,
      kanbanGasLimit) async {
    var keyPairKanban = getExgKeyPair(seed);
    var addressInKanban = keyPairKanban["address"];
    var amountInLink = BigInt.from(amount * 1e18);

    var addressInWallet = coinAddress;
    if (coinName == 'BTC' || coinName == 'FAB') {
      /*
      print('addressInWallet before');
      print(addressInWallet);
      var bytes = bs58check.decode(addressInWallet);
      print('bytes');
      print(bytes);
      addressInWallet = HEX.encode(bytes);
      print('addressInWallet after');
      print(addressInWallet);

       */
      addressInWallet = btcToBase58Address(addressInWallet);
      //no 0x appended
    } else if (tokenType == 'FAB') {
      addressInWallet = exgToFabAddress(addressInWallet);
      addressInWallet = btcToBase58Address(addressInWallet);
    }
    var coinType = getCoinTypeIdByName(coinName);
    var abiHex = getWithdrawFuncABI(coinType, amountInLink, addressInWallet);

    var coinPoolAddress = await getCoinPoolAddress();

    var nonce = await getNonce(addressInKanban);

    var txKanbanHex = await signAbiHexWithPrivateKey(
        abiHex,
        HEX.encode(keyPairKanban["privateKey"]),
        coinPoolAddress,
        nonce,
        kanbanPrice,
        kanbanGasLimit);

    var res = await sendKanbanRawTransaction(txKanbanHex);

    if (res['transactionHash'] != '') {
      res['success'] = true;
      res['data'] = res;
    } else {
      res['success'] = false;
      res['data'] = 'error';
    }
    return res;
  }

  // Future Deposit Do

  Future<Map<String, dynamic>> depositDo(
      seed, String coinName, String tokenType, double amount, option) async {
    var errRes = new Map();
    errRes['success'] = false;

    var officalAddress = getOfficalAddress(coinName);
    if (officalAddress == null) {
      errRes['data'] = 'no official address';
      return errRes;
    }
    /*
    var option = {};
    if ((coinName != null) &&
        (coinName != '') &&
        (tokenType != null) &&
        (tokenType != '')) {
      option = {
        'tokenType': tokenType,
        'contractAddress': environment["addresses"]["smartContract"][coinName]
      };
    }
    */
    var kanbanGasPrice = option['kanbanGasPrice'];
    var kanbanGasLimit = option['kanbanGasLimit'];
    var resST = await sendTransaction(
        coinName, seed, [0], [], officalAddress, amount, option, false);

    if (resST['errMsg'] != '') {
      errRes['data'] = resST['errMsg'];
      return errRes;
    }

    if (resST['txHex'] == '' || resST['txHash'] == '') {
      errRes['data'] = 'no txHex or txHash';
      return errRes;
    }

    var txHex = resST['txHex'];
    var txHash = resST['txHash'];

    var amountInLink = BigInt.from(amount * 1e18);

    var coinType = getCoinTypeIdByName(coinName);

    if (coinType == 0) {
      errRes['data'] = 'invalid coinType for ' + coinName;
      return errRes;
    }

    var keyPairKanban = getExgKeyPair(seed);
    var addressInKanban = keyPairKanban["address"];
    var originalMessage = getOriginalMessage(
        coinType,
        stringUtils.trimHexPrefix(txHash),
        amountInLink,
        stringUtils.trimHexPrefix(addressInKanban));

    var signedMess =
        await signedMessage(originalMessage, seed, coinName, tokenType);

    /*
    print('signedMess=');
    print(signedMess['r']);
    print(signedMess['s']);
    print(signedMess['v']);
    return null;

     */
    var coinPoolAddress = await getCoinPoolAddress();

    var abiHex = getDepositFuncABI(
        coinType, txHash, amountInLink, addressInKanban, signedMess);

    // print('abiHexxxxxx=' + abiHex);
    var nonce = await getNonce(addressInKanban);

    var txKanbanHex = await signAbiHexWithPrivateKey(
        abiHex,
        HEX.encode(keyPairKanban["privateKey"]),
        coinPoolAddress,
        nonce,
        kanbanGasPrice,
        kanbanGasLimit);

    var res = await submitDeposit(txHex, txKanbanHex);

    return res;
  }

  /* --------------------------------------------
              Methods Called in Send State 
  ----------------------------------------------*/

// Get Fab Transaction Status
  Future getFabTxStatus(String txId) async {
    await getFabTransactionStatus(txId);
  }

// Get Fab Transaction Balance
  Future getFabBalance(String address) async {
    await getFabBalanceByAddress(address);
  }

  // Get ETH Transaction Status
  Future getEthTxStatus(String txId) async {
    await getFabTransactionStatus(txId);
  }

// Get ETH Transaction Balance
  Future getEthBalance(String address) async {
    await getFabBalanceByAddress(address);
  }

// Future Add Gas Do
  Future<Map<String, dynamic>> addGasDo(seed, double amount) async {
    var satoshisPerBytes = 14;
    var scarContractAddress = await getScarAddress();
    scarContractAddress = stringUtils.trimHexPrefix(scarContractAddress);

    var fxnDepositCallHex = '4a58db19';
    var contractInfo = await getFabSmartContract(
        scarContractAddress, fxnDepositCallHex, 800000, 50);

    var res1 = await getFabTransactionHex(seed, [0], contractInfo['contract'],
        amount, contractInfo['totalFee'], satoshisPerBytes, [], false);
    var txHex = res1['txHex'];
    var errMsg = res1['errMsg'];

    var txHash = '';
    if (txHex != null && txHex != '') {
      var res = await _api.postFabTx(txHex);
      txHash = res['txHash'];
      errMsg = res['errMsg'];
    }

    return {'txHex': txHex, 'txHash': txHash, 'errMsg': errMsg};
  }

  convertLiuToFabcoin(amount) {
    return (amount * 1e-8);
  }

  isFabTransactionLocked(String txid, int idx) async {
    if (idx != 0) {
      return false;
    }
    var response = await _api.getFabTransactionJson(txid);

    if ((response['vin'] != null) && (response['vin'].length > 0)) {
      var vin = response['vin'][0];
      if (vin['coinbase'] != null) {
        if (response['onfirmations'] <= 800) {
          return true;
        }
      }
    }
    return false;
  }

  getFabTransactionHex(
      seed,
      addressIndexList,
      toAddress,
      double amount,
      double extraTransactionFee,
      int satoshisPerBytes,
      addressList,
      getTransFeeOnly) async {
    final txb = new TransactionBuilder(
        network: environment["chains"]["BTC"]["network"]);
    final root = bip32.BIP32.fromSeed(seed);
    var totalInput = 0;
    var changeAddress = '';
    var finished = false;
    var receivePrivateKeyArr = [];

    var totalAmount = amount + extraTransactionFee;
    var amountNum = totalAmount * 1e8;
    amountNum += (2 * 34 + 10) * satoshisPerBytes;

    var transFeeDouble = 0.0;
    var bytesPerInput = environment["chains"]["FAB"]["bytesPerInput"];
    var feePerInput = bytesPerInput * satoshisPerBytes;

    for (var i = 0; i < addressIndexList.length; i++) {
      var index = addressIndexList[i];
      var fabCoinChild = root.derivePath("m/44'/" +
          environment["CoinType"]["FAB"].toString() +
          "'/0'/0/" +
          index.toString());
      var fromAddress = getBtcAddressForNode(fabCoinChild);
      if (addressList != null && addressList.length > 0) {
        fromAddress = addressList[i];
      }
      if (i == 0) {
        changeAddress = fromAddress;
      }
      final privateKey = fabCoinChild.privateKey;
      var utxos = await _api.getFabUtxos(fromAddress);
      if ((utxos != null) && (utxos.length > 0)) {
        for (var j = 0; j < utxos.length; j++) {
          var utxo = utxos[j];
          var idx = utxo['idx'];
          var txid = utxo['txid'];
          var value = utxo['value'];
          /*
          var isLocked = await isFabTransactionLocked(txid, idx);
          if (isLocked) {
            continue;
          }
           */
          txb.addInput(txid, idx);
          receivePrivateKeyArr.add(privateKey);
          totalInput += value;

          amountNum -= value;
          amountNum += feePerInput;
          if (amountNum <= 0) {
            finished = true;
            break;
          }
        }
      }

      if (!finished) {
        return {
          'txHex': '',
          'errMsg': 'not enough fab coin to make the transaction.',
          'transFee': transFeeDouble
        };
      }

      var transFee = (receivePrivateKeyArr.length) * feePerInput +
          (2 * 34 + 10) * satoshisPerBytes;
      print('extraTransactionFee==' + extraTransactionFee.toString());
      print('transFee==' + transFee.toString());
      transFeeDouble = ((Decimal.parse(extraTransactionFee.toString()) +
              Decimal.parse(transFee.toString()) / Decimal.parse('1e8')))
          .toDouble();
      var output1 =
          (totalInput - amount * 1e8 - extraTransactionFee * 1e8 - transFee)
              .round();

      if (getTransFeeOnly) {}
      var output2 = (amount * 1e8).round();

      if (output1 < 0 || output2 < 0) {
        return {
          'txHex': '',
          'errMsg': 'output1 or output2 should be greater than 0.',
          'transFee': transFeeDouble
        };
      }

      txb.addOutput(changeAddress, output1);
      txb.addOutput(toAddress, output2);

      for (var i = 0; i < receivePrivateKeyArr.length; i++) {
        var privateKey = receivePrivateKeyArr[i];
        var alice = ECPair.fromPrivateKey(privateKey,
            compressed: true, network: environment["chains"]["BTC"]["network"]);

        txb.sign(i, alice);
      }

      var txHex = txb.build().toHex();

      return {'txHex': txHex, 'errMsg': '', 'transFee': transFeeDouble};
    }
  }

  Future getErrDeposit(String address) {
    return getKanbanErrDeposit(address);
  }
  // Send Transaction

  Future sendTransaction(
      String coin,
      seed,
      List addressIndexList,
      List addressList,
      String toAddress,
      double amount,
      options,
      bool doSubmit) async {
    final root = bip32.BIP32.fromSeed(seed);

    var totalInput = 0;
    var finished = false;
    var gasPrice = 0;
    var gasLimit = 0;
    var satoshisPerBytes = 0;
    var bytesPerInput = 0;
    var getTransFeeOnly = false;
    var txHex = '';
    var txHash = '';
    var errMsg = '';
    var transFeeDouble = 0.0;
    var amountSent = 0;
    var receivePrivateKeyArr = [];

    var tokenType = options['tokenType'] ?? '';
    var contractAddress = options['contractAddress'] ?? '';
    var changeAddress = '';

    if (options != null) {
      if (options["gasPrice"] != null) {
        gasPrice = options["gasPrice"];
      }
      if (options["gasLimit"] != null) {
        gasLimit = options["gasLimit"];
      }
      if (options["satoshisPerBytes"] != null) {
        satoshisPerBytes = options["satoshisPerBytes"];
      }
      if (options["bytesPerInput"] != null) {
        bytesPerInput = options["bytesPerInput"];
      }
      if (options["getTransFeeOnly"] != null) {
        getTransFeeOnly = options["getTransFeeOnly"];
      }
    }
    //print('tokenType=' + tokenType);

    log.w('gasPrice=' + gasPrice.toString());
    log.w('gasLimit=' + gasLimit.toString());
    log.w('satoshisPerBytes=' + satoshisPerBytes.toString());
    if (coin == 'BTC') {
      if (bytesPerInput == 0) {
        bytesPerInput = environment["chains"]["BTC"]["bytesPerInput"];
      }
      if (satoshisPerBytes == 0) {
        satoshisPerBytes = environment["chains"]["BTC"]["satoshisPerBytes"];
      }
      var amountNum = amount * 1e8;
      amountNum += (2 * 34 + 10) * satoshisPerBytes;
      final txb = new TransactionBuilder(
          network: environment["chains"]["BTC"]["network"]);
      // txb.setVersion(1);

      for (var i = 0; i < addressIndexList.length; i++) {
        var index = addressIndexList[i];
        var bitCoinChild = root.derivePath("m/44'/" +
            environment["CoinType"]["BTC"].toString() +
            "'/0'/0/" +
            index.toString());
        var fromAddress = getBtcAddressForNode(bitCoinChild);
        if (addressList.length > 0) {
          fromAddress = addressList[i];
        }
        if (i == 0) {
          changeAddress = fromAddress;
        }
        final privateKey = bitCoinChild.privateKey;
        var utxos = await _api.getBtcUtxos(fromAddress);
        //print('utxos=');
        //print(utxos);
        if ((utxos == null) || (utxos.length == 0)) {
          continue;
        }
        for (var j = 0; j < utxos.length; j++) {
          var tx = utxos[j];
          if (tx['idx'] < 0) {
            continue;
          }
          txb.addInput(tx['txid'], tx['idx']);
          amountNum -= tx['value'];
          amountNum += bytesPerInput * satoshisPerBytes;
          totalInput += tx['value'];
          receivePrivateKeyArr.add(privateKey);
          if (amountNum <= 0) {
            finished = true;
            break;
          }
        }
      }

      if (!finished) {
        txHex = '';
        txHash = '';
        errMsg = 'not enough fund.';
        return {'txHex': txHex, 'txHash': txHash, 'errMsg': errMsg};
      }

      var transFee =
          (receivePrivateKeyArr.length) * bytesPerInput * satoshisPerBytes +
              (2 * 34 + 10) * satoshisPerBytes;
      transFeeDouble = transFee / 1e8;

      if (getTransFeeOnly) {
        return {
          'txHex': '',
          'txHash': '',
          'errMsg': '',
          'amountSent': '',
          'transFee': transFeeDouble
        };
      }

      var output1 = (totalInput - amount * 1e8 - transFee).round();
      var output2 = (amount * 1e8).round();

      txb.addOutput(changeAddress, output1);
      txb.addOutput(toAddress, output2);
      for (var i = 0; i < receivePrivateKeyArr.length; i++) {
        var privateKey = receivePrivateKeyArr[i];
        var alice = ECPair.fromPrivateKey(privateKey,
            compressed: true, network: environment["chains"]["BTC"]["network"]);
        txb.sign(i, alice);
      }

      var tx = txb.build();
      txHex = tx.toHex();
      if (doSubmit) {
        var res = await _api.postBtcTx(txHex);
        txHash = res['txHash'];
        errMsg = res['errMsg'];
        return {'txHash': txHash, 'errMsg': errMsg};
      } else {
        txHash = '0x' + tx.getId();
      }
    }

    // ETH Transaction

    else if (coin == 'ETH') {
      // Credentials fromHex = EthPrivateKey.fromHex("c87509a[...]dc0d3");

      if (gasPrice == 0) {
        gasPrice = environment["chains"]["ETH"]["gasPrice"];
      }
      if (gasLimit == 0) {
        gasLimit = environment["chains"]["ETH"]["gasLimit"];
      }
      transFeeDouble = (Decimal.parse(gasPrice.toString()) *
              Decimal.parse(gasLimit.toString()) /
              Decimal.parse('1e18'))
          .toDouble();
      if (getTransFeeOnly) {
        return {
          'txHex': '',
          'txHash': '',
          'errMsg': '',
          'amountSent': '',
          'transFee': transFeeDouble
        };
      }

      final chainId = environment["chains"]["ETH"]["chainId"];
      final ethCoinChild = root.derivePath(
          "m/44'/" + environment["CoinType"]["ETH"].toString() + "'/0'/0/0");
      final privateKey = HEX.encode(ethCoinChild.privateKey);
      var amountSentInt = BigInt.from(amount * 1e18);
      Credentials credentials = EthPrivateKey.fromHex(privateKey);

      final address = await credentials.extractAddress();
      final addressHex = address.hex;
      final nonce = await _api.getEthNonce(addressHex);

      var apiUrl =
          environment["chains"]["ETH"]["infura"]; //Replace with your API

      var httpClient = new http.Client();
      var ethClient = new Web3Client(apiUrl, httpClient);

      final signed = await ethClient.signTransaction(
          credentials,
          Transaction(
            nonce: nonce,
            to: EthereumAddress.fromHex(toAddress),
            gasPrice:
                EtherAmount.fromUnitAndValue(EtherUnit.wei, gasPrice.round()),
            maxGas: gasLimit,
            value: EtherAmount.fromUnitAndValue(EtherUnit.wei, amountSentInt),
          ),
          chainId: chainId,
          fetchChainIdFromNetworkId: false);

      txHex = '0x' + HEX.encode(signed);

      print('txHex in ETH=' + txHex);
      if (doSubmit) {
        var res = await _api.postEthTx(txHex);
        txHash = res['txHash'];
        errMsg = res['errMsg'];
      } else {
        txHash = getTransactionHash(signed);
      }
    } else if (coin == 'FAB') {
      if (bytesPerInput == 0) {
        bytesPerInput = environment["chains"]["FAB"]["bytesPerInput"];
      }
      if (satoshisPerBytes == 0) {
        satoshisPerBytes = environment["chains"]["FAB"]["satoshisPerBytes"];
      }

      var res1 = await getFabTransactionHex(seed, addressIndexList, toAddress,
          amount, 0, satoshisPerBytes, addressList, getTransFeeOnly);
      if (getTransFeeOnly) {
        return {
          'txHex': '',
          'txHash': '',
          'errMsg': '',
          'amountSent': '',
          'transFee': res1["transFee"]
        };
      }
      txHex = res1['txHex'];
      errMsg = res1['errMsg'];
      if ((errMsg == '') && (txHex != '')) {
        if (doSubmit) {
          var res = await _api.postFabTx(txHex);

          txHash = res['txHash'];
          errMsg = res['errMsg'];
        } else {
          var tx = btcTransaction.Transaction.fromHex(txHex);
          txHash = '0x' + tx.getId();
        }
      }
    } else if (tokenType == 'FAB') {
      if (bytesPerInput == 0) {
        bytesPerInput = environment["chains"]["FAB"]["bytesPerInput"];
      }
      if (satoshisPerBytes == 0) {
        satoshisPerBytes = environment["chains"]["FAB"]["satoshisPerBytes"];
      }
      if (gasPrice == 0) {
        gasPrice = environment["chains"]["FAB"]["gasPrice"];
      }
      if (gasLimit == 0) {
        gasLimit = environment["chains"]["FAB"]["gasLimit"];
      }
      var transferAbi = 'a9059cbb';
      var amountSentInt = BigInt.from(amount * 1e18);

      var amountSentHex = amountSentInt.toRadixString(16);

      var fxnCallHex = transferAbi +
          stringUtils.fixLength(stringUtils.trimHexPrefix(toAddress), 64) +
          stringUtils.fixLength(stringUtils.trimHexPrefix(amountSentHex), 64);

      contractAddress = stringUtils.trimHexPrefix(contractAddress);

      var contractInfo = await getFabSmartContract(
          contractAddress, fxnCallHex, gasLimit, gasPrice);

      if (addressList != null && addressList.length > 0) {
        addressList[0] = exgToFabAddress(addressList[0]);
      }

      var res1 = await getFabTransactionHex(
          seed,
          addressIndexList,
          contractInfo['contract'],
          0,
          contractInfo['totalFee'],
          satoshisPerBytes,
          addressList,
          getTransFeeOnly);

      print('res1 in here=');
      print(res1);

      if (getTransFeeOnly) {
        return {
          'txHex': '',
          'txHash': '',
          'errMsg': '',
          'amountSent': '',
          'transFee': res1["transFee"]
        };
      }

      txHex = res1['txHex'];
      errMsg = res1['errMsg'];
      if (txHex != null && txHex != '') {
        if (doSubmit) {
          var res = await _api.postFabTx(txHex);
          txHash = res['txHash'];
          errMsg = res['errMsg'];
        } else {
          var tx = btcTransaction.Transaction.fromHex(txHex);
          txHash = '0x' + tx.getId();
        }
      }
    } else if (tokenType == 'ETH') {
      if (gasPrice == 0) {
        gasPrice = environment["chains"]["ETH"]["gasPrice"];
      }
      if (gasLimit == 0) {
        gasLimit = environment["chains"]["ETH"]["gasLimit"];
      }
      transFeeDouble = (Decimal.parse(gasPrice.toString()) *
              Decimal.parse(gasLimit.toString()) /
              Decimal.parse('1e18'))
          .toDouble();
      log.w('transFeeDouble===' + transFeeDouble.toString());
      if (getTransFeeOnly) {
        return {
          'txHex': '',
          'txHash': '',
          'errMsg': '',
          'amountSent': '',
          'transFee': transFeeDouble
        };
      }

      final chainId = environment["chains"]["ETH"]["chainId"];
      final ethCoinChild = root.derivePath(
          "m/44'/" + environment["CoinType"]["ETH"].toString() + "'/0'/0/0");
      final privateKey = HEX.encode(ethCoinChild.privateKey);
      Credentials credentials = EthPrivateKey.fromHex(privateKey);

      final address = await credentials.extractAddress();
      final addressHex = address.hex;
      final nonce = await _api.getEthNonce(addressHex);
      gasLimit = 100000;
      var amountSentInt = BigInt.from(amount * 1e6);
      var transferAbi = 'a9059cbb';
      var fxnCallHex = transferAbi +
          stringUtils.fixLength(stringUtils.trimHexPrefix(toAddress), 64) +
          stringUtils.fixLength(
              stringUtils.trimHexPrefix(amountSentInt.toRadixString(16)), 64);
      var apiUrl =
          environment["chains"]["ETH"]["infura"]; //Replace with your API

      var httpClient = new http.Client();
      var ethClient = new Web3Client(apiUrl, httpClient);

      final signed = await ethClient.signTransaction(
          credentials,
          Transaction(
              nonce: nonce,
              to: EthereumAddress.fromHex(contractAddress),
              gasPrice:
                  EtherAmount.fromUnitAndValue(EtherUnit.wei, gasPrice.round()),
              maxGas: gasLimit,
              value: EtherAmount.fromUnitAndValue(EtherUnit.wei, 0),
              data: Uint8List.fromList(stringUtils.hex2Buffer(fxnCallHex))),
          chainId: chainId,
          fetchChainIdFromNetworkId: false);
      log.w('signed=');
      txHex = '0x' + HEX.encode(signed);

      if (doSubmit) {
        var res = await _api.postEthTx(txHex);
        txHash = res['txHash'];
        errMsg = res['errMsg'];
      } else {
        txHash = getTransactionHash(signed);
      }
    }
    return {
      'txHex': txHex,
      'txHash': txHash,
      'errMsg': errMsg,
      'amountSent': amountSent,
      'transFee': transFeeDouble
    };
  }

  getFabSmartContract(
      String contractAddress, String fxnCallHex, gasLimit, gasPrice) async {
    contractAddress = stringUtils.trimHexPrefix(contractAddress);
    fxnCallHex = stringUtils.trimHexPrefix(fxnCallHex);

    var totalAmount = (Decimal.parse(gasLimit.toString()) *
            Decimal.parse(gasPrice.toString()) /
            Decimal.parse('1e8'))
        .toDouble();
    // let cFee = 3000 / 1e8 // fee for the transaction

    var totalFee = totalAmount;
    var chunks = new List<dynamic>();
    chunks.add(84);
    chunks.add(Uint8List.fromList(stringUtils.number2Buffer(gasLimit)));
    chunks.add(Uint8List.fromList(stringUtils.number2Buffer(gasPrice)));
    chunks.add(Uint8List.fromList(stringUtils.hex2Buffer(fxnCallHex)));
    chunks.add(Uint8List.fromList(stringUtils.hex2Buffer(contractAddress)));
    chunks.add(194);

    var contract = script.compile(chunks);

    var contractSize = contract.toString().length;

    totalFee += convertLiuToFabcoin(contractSize * 10);

    var res = {'contract': contract, 'totalFee': totalFee};
    return res;
  }
}
