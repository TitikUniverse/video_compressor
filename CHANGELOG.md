## 0.0.5

* Change the feedback of pre-check

## 0.0.4

* Change the minSdkVersion to 28 to be compatible old app

## 0.0.3

* Remove the failed file from cache folder.

## 0.0.2

* Add exception handler for iOS. Sometimes, audioWriterInput.isReadyForMoreMediaData cannot be false after audioWriterInput.markAsFinished(). The plugin will return compression failed temporarily.

We 90% for sure this is caused by the audio track of source video not compatible, and try to fix it in the future.

## 0.0.1

* v0.0.1
