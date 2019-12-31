import 'package:exchangilymobileapp/logger.dart';
import 'package:exchangilymobileapp/service_locator.dart';
import 'package:exchangilymobileapp/services/wallet_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/globals.dart' as globals;
import 'package:exchangilymobileapp/environments/environment.dart';
class ConfirmMnemonictWalletScreen extends StatefulWidget {
  final List<String> mnemonic;
  const ConfirmMnemonictWalletScreen({Key key, this.mnemonic})
      : super(key: key);

  @override
  _ConfirmMnemonictWalletScreenState createState() =>
      _ConfirmMnemonictWalletScreenState();
}

class _ConfirmMnemonictWalletScreenState
    extends State<ConfirmMnemonictWalletScreen> {
  final log = getLogger('Confirm Seed');
  List<TextEditingController> _mnemonicTextController = new List();
  List<String> userTypedMnemonic = [];
  FocusNode _focusNode;
  final int _count = 12;
  WalletService _walletService = locator<WalletService>();

  @override
  void initState() {
    _mnemonicTextController.clear();
    super.initState();
  }

  @override
  void dispose() {
    _mnemonicTextController.map((f) => f.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Top Text Row Widget
    Widget topTextRow = Row(
      children: <Widget>[
        Expanded(
            child: Text(
          'Please type in your 12 word seed phrase in the correct sequence to confirm',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headline,
        )),
      ],
    );
// Finish Wallet Backup Button Widget

    Widget finishWalletBackupButton = Container(
      padding: EdgeInsets.all(15),
      child: RaisedButton(
        child: Text(
          'Finish Wallet Backup',
          style: Theme.of(context).textTheme.button,
        ),
        onPressed: () {
          checkMnemonic();
        },
      ),
    );

// Scaffold

    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          title: Text('Confirm Seed Phrase'),
          backgroundColor: globals.secondaryColor),
      body: Container(
        padding: EdgeInsets.all(10),
        child: ListView(
          scrollDirection: Axis.vertical,
          children: <Widget>[
            topTextRow,
            Container(
              margin: EdgeInsets.symmetric(
                vertical: 40,
              ),
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 5),
              child: _buttonGrid(),
            ),
            finishWalletBackupButton
          ],
        ),
      ),
    );
  }

  // Button Grid

  Widget _buttonGrid() => GridView.extent(
      maxCrossAxisExtent: 125,
      padding: const EdgeInsets.all(2),
      mainAxisSpacing: 15,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      childAspectRatio: 2,
      children: _buildButtonGrid(_count));

  // Test Build Button Grid

  List<Container> _buildButtonGri(int count) => List.generate(count, (i) {
        _mnemonicTextController.add(TextEditingController());
        return Container(
          child: TextField(
            focusNode: _focusNode,
            controller: _mnemonicTextController[i],
            style: TextStyle(color: globals.white),
            decoration: InputDecoration(
                hintText: '$i', hintStyle: TextStyle(color: globals.white)),
          ),
        );
      });

  // Check Mnemonic Values

  checkMnemonic() {
    setState(() {
      userTypedMnemonic.clear();
      for (var i = 0; i < _count; i++) {
        userTypedMnemonic.add(_mnemonicTextController[i].text);
      }
      // Collections in Dart have no inherent equality.
      // Two sets are not equal, even if they contain exactly the same objects as elements.
      // So we use listEqual for deep checking which is one many methods
      if (isLocal || listEquals(widget.mnemonic, userTypedMnemonic)) {
        Navigator.of(context).pushNamed('/createPassword');
        log.w('if');
        log.w(widget.mnemonic);
        log.w('user typed');
        log.w(userTypedMnemonic);
        // userTypedMnemonic.clear();

      } else {
        // Remove this after next screen has finished
        // Navigator.of(context).pushNamed('/createPassword');
        // May be in future we should display where user made a mistake in typing
        // For example text field index 5 should turn red if user made a mistake there
        log.w('else');
        log.w(widget.mnemonic);
        log.w('user typed');
        log.w(userTypedMnemonic);
        _walletService.showInfoFlushbar(
            'Seed Empty',
            'Please fill all the text fields',
            Icons.cancel,
            Colors.red,
            context);
      }
    });
  }

  // Build Button Grid

  List<Container> _buildButtonGrid(int count) => List.generate(
        count,
        (i) {
          // to show the number in the text field which should look like that it starts from 1 for user's ease
          var hintMnemonicWordNumber = i + 1;
          _mnemonicTextController.add(TextEditingController());
          return Container(
            child: TextField(
              inputFormatters: <TextInputFormatter>[
                WhitelistingTextInputFormatter(RegExp(r'([a-z]{0,})$'))
              ],
              style: TextStyle(color: globals.white),
              controller: _mnemonicTextController[i],
              //maxLines: 2,
              autocorrect: false,
              decoration: InputDecoration(
                fillColor: globals.primaryColor,
                filled: true,
                hintText: '$hintMnemonicWordNumber)',
                hintStyle: TextStyle(color: globals.white),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: globals.white, width: 2),
                    borderRadius: BorderRadius.circular(30.0)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          );
        },
      );
}
