import './string_util.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:hex/hex.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/src/utils/rlp.dart' as rlp;
import 'dart:typed_data';

getDepositFuncABI(int coinType, String txHash, BigInt amountInLink, String addressInKanban, signedMessage) {
  var abiHex = "379eb862";
  print('signedMessage.v=');
  print(signedMessage["v"]);
  abiHex += trimHexPrefix(signedMessage["v"]);
  abiHex += fixLength(coinType.toString(), 62);
  abiHex += trimHexPrefix(txHash);
  var amountHex = amountInLink.toRadixString(16);
  abiHex += fixLength(amountHex, 64);
  abiHex += fixLength(trimHexPrefix(addressInKanban), 64);
  abiHex += trimHexPrefix(signedMessage["r"]);
  abiHex += trimHexPrefix(signedMessage["s"]);
  return abiHex;
}

List<dynamic> _encodeToRlp(Transaction transaction, MsgSignature signature) {
  final list = [
    transaction.nonce,
    transaction.gasPrice.getInWei,
    transaction.maxGas,
  ];

  if (transaction.to != null) {
    list.add(transaction.to.addressBytes);
  } else {
    list.add('');
  }

  list..add(transaction.value.getInWei);
  list.add('');
  list..add(transaction.data);

  if (signature != null) {
    list..add(signature.v)..add(signature.r)..add(signature.s);
  }

  return list;
}

Uint8List uint8ListFromList(List<int> data) {
  if (data is Uint8List) return data;

  return Uint8List.fromList(data);
}

Future signAbiHexWithPrivateKey(String abiHex, String privateKey, String coinPoolAddress, int nonce) async{

  var chainId = 212;
  var apiUrl = "https://ropsten.infura.io/v3/6c5bdfe73ef54bbab0accf87a6b4b0ef"; //Replace with your API

  var httpClient = new http.Client();

  abiHex = trimHexPrefix(abiHex);
  var ethClient = new Web3Client(apiUrl, httpClient);
  var credentials = await ethClient.credentialsFromPrivateKey(privateKey);


  var transaction = Transaction(
      to: EthereumAddress.fromHex(coinPoolAddress),
      gasPrice: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 4),
      maxGas: 20000000,
      nonce: nonce,
      value: EtherAmount.fromUnitAndValue(EtherUnit.wei, 0),
      data: HEX.decode(abiHex)
  );
  final innerSignature =
  chainId == null ? null : MsgSignature(BigInt.zero, BigInt.zero, chainId);

  var transactionList = _encodeToRlp(transaction, innerSignature);
  final encoded =
  uint8ListFromList(rlp.encode(transactionList));

  print('transactionList=');
  print(transactionList);
  print('encodedstring=');
  print(HEX.encode(encoded));
  final signature = await credentials.signToSignature(encoded, chainId: chainId);

  print('chainId=');
  print(chainId);
  print('signature=');
  print(signature.r.toString());
  print(signature.s.toString());
  print(signature.v.toString());
  var encodeList = uint8ListFromList(rlp.encode(_encodeToRlp(transaction, signature)));
  return '0x' + HEX.encode(encodeList);
  /*
  var signed = await ethClient.signTransaction(
    credentials,
    Transaction(
      to: EthereumAddress.fromHex(coinPoolAddress),
      gasPrice: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 4),
      maxGas: 20000000,
      nonce: nonce,
      data: HEX.decode(abiHex)
    ),
  );
  return HEX.encode(signed);

   */
}