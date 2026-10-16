import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';
import '../widgets/order_receipt.dart';

/// Save receipt / Share: draws the receipt as a PNG (screenshot), then saves it
/// (file_saver: a download on the web, a file on a phone) or opens the share
/// sheet (share_plus, which downloads on browsers that cannot share files).
class ReceiptExport {
  const ReceiptExport();

  static String fileName(Order order) => 'receipt-${order.number}';

  Future<Uint8List> image(BuildContext context, Order order, {DateTime? paidAt}) => ScreenshotController().captureFromWidget(
        Material(
          color: const Color(0xFFF5F9FC),
          child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), child: OrderReceipt(order: order, paidAt: paidAt)),
        ),
        context: context,
        pixelRatio: 3,
        delay: const Duration(milliseconds: 60),
      );

  Future<void> save(Uint8List png, Order order) =>
      FileSaver.instance.saveFile(name: fileName(order), bytes: png, fileExtension: 'png', mimeType: MimeType.png);

  Future<void> share(Uint8List png, Order order) => SharePlus.instance.share(ShareParams(
        text: 'Receipt for order ${order.number} - Anime World Shop',
        files: [XFile.fromData(png, mimeType: 'image/png', name: '${fileName(order)}.png')],
      ));
}
