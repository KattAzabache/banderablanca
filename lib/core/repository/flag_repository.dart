import 'dart:io';

import 'package:banderablanca/core/helpers/helpers.dart';
import 'package:banderablanca/core/models/media_content.dart';
import 'package:banderablanca/core/models/thumbnail_info.dart';
import 'package:banderablanca/ui/shared/shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:meta/meta.dart';
import 'package:mime/mime.dart';
import '../../core/abstract/abstract.dart';
import '../../core/models/white_flag.dart';
import 'storage_repository.dart';
import 'package:path/path.dart';

class FlagRepository implements FlagRepositoryAbs {
  FlagRepository({
    @required this.firestore,
    @required this.auth,
    @required this.storage,
  });

  final Firestore firestore;
  final FirebaseAuth auth;
  final FirebaseStorage storage;

  static String path = "flags";

  @override
  Future<bool> createFlag(WhiteFlag newFlag, String mediaPath) async {
    final FirebaseUser firebaseUser = await auth.currentUser();
    final _doc = firestore.collection(path).document();
    final StorageRepository storageRepository = StorageRepository(storage);
    String downloadUrl =
        await storageRepository.uploadFile(mediaPath, _doc.documentID, path);
    ThumbnailInfo thumbInfo;
    thumbInfo = await genThumbnail(mediaPath);
    String thumbUrl = await storageRepository.uploadFileData(
        thumbInfo.filePath, thumbInfo.imageData, _doc.documentID, path);
    thumbInfo = thumbInfo.copyWith(downloadUrl: thumbUrl);
    final MediaContent mediaContent = MediaContent(
      mimeType: lookupMimeType(mediaPath),
      downloadUrl: downloadUrl,
      size: File(mediaPath).lengthSync(),
      name: basename(mediaPath),
      thumbnailInfo: thumbInfo,
    );

    WhiteFlag _data = newFlag.copyWith(
      senderName: firebaseUser.displayName,
      senderPhotoUrl: firebaseUser.photoUrl,
      uid: firebaseUser.uid,
      photoUrl: downloadUrl,
      mediaContent: mediaContent,
    );

    Map<String, dynamic> _message = _data.toJson();

    _message['timestamp'] = FieldValue.serverTimestamp();

    return _doc.setData(_message).then((onValue) {
      return true;
    }).catchError((onError) {
      return false;
    });
  }

  @override
  Stream<List<WhiteFlag>> streamFlags() {
    return firestore
        .collection(path)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((onError) {
      print(onError);
    }).map((snapshot) {
      return snapshot.documents.map((DocumentSnapshot doc) {
        final WhiteFlag flag = WhiteFlag.fromJson(doc.data);
        return flag.copyWith(id: doc.documentID);
      }).toList();
    });
  }
}
