import QtQuick 2.0
import Sailfish.Silica 1.0
import TelegramModels 1.0
import tdlibQtEnums 1.0
import QtMultimedia 5.6
import "../components"
ListItem {
    id: messageListItem
    width: parent.width
    contentHeight: columnWrapper.height

    Column {
        id: columnWrapper
        width: contentWrapper.width
        height: contentWrapper.height
        anchors.right: is_outgoing ? parent.right : undefined
        anchors.left: is_outgoing ? undefined : parent.left
        anchors.rightMargin: Theme.horizontalPageMargin
        anchors.leftMargin: Theme.horizontalPageMargin

        Row {
            id: contentWrapper
            spacing: Theme.paddingMedium
            width: userAvatar.width + contentLoader.width + spacing
            height: Math.max(userAvatar.height,contentLoader.height)
            layoutDirection: is_outgoing ? Qt.RightToLeft : Qt.LeftToRight

            CircleImage {
                id: userAvatar
                width: visible ? Theme.itemSizeExtraSmall : 0
                anchors.top: contentLoader.top
                source: sender_photo ? "image://depecherDb/"+sender_photo : ""
                fallbackText: author ? author.charAt(0) : ""
                fallbackItemVisible: sender_photo ? false : true
                visible: !is_outgoing && message_type != MessagingModel.SYSTEM_NEW_MESSAGE &&
                         !messagingModel.chatType["is_channel"]  &&
                         messagingModel.chatType["type"] != TdlibState.Private &&
                         messagingModel.chatType["type"] != TdlibState.Secret
            }
            Column {
                id: contentLoader

                Row {
                    id: subInfoRow
                    width: parent.width

                    Label {
                        id: authorName
                        text: author ? author : ""
                        color: pressed ? Theme.highlightColor: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                        visible: {
                            if(message_type == MessagingModel.SYSTEM_NEW_MESSAGE) {
                                return false
                            }
                            else if(messagingModel.chatType["type"] == TdlibState.BasicGroup || (messagingModel.chatType["type"] == TdlibState.Supergroup && !messagingModel.chatType["is_channel"])) {
                                return true
                            }

                            return false
                        }
                    }
                }

                Loader {
                    sourceComponent: {
                        if(message_type == MessagingModel.TEXT) {
                            return textContent
                        }
                        else if(message_type == MessagingModel.PHOTO) {
                            return imageContent
                        }
                        else if(message_type == MessagingModel.STICKER) {
                            return stickerContent
                        }
                        else if(message_type == MessagingModel.SYSTEM_NEW_MESSAGE) {
                            return newMessageContent
                        }
                        else if(message_type == MessagingModel.DOCUMENT) {
                            return documentContent
                        }
                        else if(message_type == MessagingModel.ANIMATION) {
                            return animationContent
                        }
                        return undefined
                    }

                }
                Row {
                    id: metaInfoRow
                    visible: message_type !== MessagingModel.SYSTEM_NEW_MESSAGE
                    width: parent.width
                    layoutDirection: is_outgoing ? Qt.RightToLeft : Qt.LeftToRight
                    spacing: Theme.paddingSmall

                    Label {
                        function timestamp(dateTime){
                            var dateTimeDate=new Date(dateTime*1000)
                            var datetime_day = dateTimeDate.getDay()
                            var currentDay = new Date().getDay()

                            if (datetime_day==currentDay)
                                return Format.formatDate(dateTimeDate, Formatter.TimeValue)
                            else
                                return Format.formatDate(dateTimeDate, Formatter.DateMediumWithoutYear)
                        }
                        font.pixelSize: Theme.fontSizeTiny
                        color:pressed ? Theme.primaryColor : Theme.secondaryColor
                        text:timestamp(date)
                    }

                    Label {
                        font.pixelSize: Theme.fontSizeTiny
                        visible: sending_state === MessagingModel.Sending_Pending || sending_state === MessagingModel.Sending_Failed
                                 ||  messagingModel.chatType["type"] == TdlibState.Private || messagingModel.chatType["type"] == TdlibState.Secret
                        text: {
                            if(sending_state === MessagingModel.Sending_Pending) {
                                return "<b>\u23F1</b>" // clock
                            }
                            else if(sending_state === MessagingModel.Sending_Failed) {
                                return "<b>\u26A0</b>" // warning sign
                            }
                            else if(sending_state == MessagingModel.Sending_Read) {
                                return "<b>\u2713\u2713</b>" // double check mark
                            }
                            else {
                                return "<b>\u2713</b>" // check mark
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: textContent

        Column{
            id: textColumn
            width: textItem.width

            LinkedLabel {
                id: textItem
                width: text.length<32 ? paintedWidth : Screen.width * 2 /3 - Theme.horizontalPageMargin * 2
                plainText:content ? content : ""
                color: pressed ? Theme.secondaryColor : Theme.primaryColor
                linkColor: pressed ? Theme.secondaryHighlightColor : Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
    }

    Component {
        id: imageContent

        Column{
            width: image.maxWidth
            Image {
                id: image
                asynchronous: true
                property int maxWidth: Screen.width-Theme.itemSizeExtraSmall - Theme.paddingMedium - 2*Theme.horizontalPageMargin
                property int maxHeight: Screen.height/2
                width: photo_aspect > 1 ? maxWidth : maxHeight * photo_aspect
                height: photo_aspect > 1 ? maxWidth/photo_aspect : maxHeight
                fillMode: Image.PreserveAspectFit
                source: "image://depecherDb/"+content

                MouseArea{
                    anchors.fill: parent
                    enabled: file_downloading_completed
                    onClicked: pageStack.push("../PicturePage.qml",{imagePath:content})
                }

                ProgressCircle {
                    id: progress
                    anchors.centerIn: parent
                    visible: file_is_uploading || file_is_downloading
                    value : file_is_uploading ? file_uploaded_size / file_downloaded_size :
                                                file_downloaded_size / file_uploaded_size
                }

                Image {
                    id: downloadIcon
                    visible: !file_downloading_completed || progress.visible
                    source: progress.visible ? "image://theme/icon-s-clear-opaque-cross"
                                             : "image://theme/icon-s-update"
                    anchors.centerIn: parent

                    MouseArea {
                        enabled: parent.visible
                        anchors.fill: parent
                        onClicked: {
                            if(progress.visible)
                                if(file_is_downloading)
                                    messagingModel.cancelDownload(index)
                                else
                                    messagingModel.deleteMessage(index)
                            else
                                messagingModel.downloadDocument(index)
                        }
                    }
                }

            }

            LinkedLabel {
                width: parent.width
                plainText: file_caption
                color: pressed ? Theme.secondaryColor :Theme.primaryColor
                linkColor: pressed ? Theme.secondaryHighlightColor :Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: file_caption === "" ? false : true
            }
        }
    }

    Component {
        id: documentContent

        Column{
            property int maxWidth: Screen.width *2/3 - Theme.horizontalPageMargin * 2
            width: maxWidth

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                enabled: file_downloading_completed && !file_is_uploading
                onClicked: Qt.openUrlExternally("file://"+content)

                Row {
                    id: documentRowWrapper
                    width: parent.width
                    spacing: Theme.paddingMedium
                    height: parent.height

                    Image {
                        id: image
                        fillMode: Image.PreserveAspectFit
                        source: "image://theme/icon-m-file-document"
                        anchors.verticalCenter: parent.verticalCenter

                        ProgressCircle {
                            id: progress
                            anchors.fill: parent
                            visible: file_is_uploading || file_is_downloading
                            value : file_is_uploading ? file_uploaded_size / file_downloaded_size :
                                                        file_downloaded_size / file_uploaded_size
                        }

                        Image {
                            id: downloadIcon
                            visible: !file_downloading_completed || progress.visible
                            source: progress.visible ? "image://theme/icon-s-clear-opaque-cross"
                                                     : "image://theme/icon-s-update"
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            enabled: downloadIcon.visible
                            anchors.fill: parent
                            onClicked: {
                                if(progress.visible)
                                    if(file_is_downloading)
                                        messagingModel.cancelDownload(index)
                                    else
                                        messagingModel.deleteMessage(index)
                                else
                                    messagingModel.downloadDocument(index)
                            }
                        }

                    }

                    Column {
                        width: parent.width - image.width - parent.spacing
                        spacing: Theme.paddingSmall
                        anchors.verticalCenter: image.verticalCenter

                        Label {
                            width: parent.width
                            elide: Text.ElideMiddle
                            color: pressed ? Theme.secondaryColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            text: document_name
                        }

                        Label {

                            color: pressed ? Theme.primaryColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeTiny
                            text: Format.formatFileSize(file_downloaded_size) + "/"
                                  + Format.formatFileSize(file_uploaded_size)
                        }
                    }
                }
            }

            LinkedLabel {
                width: documentRowWrapper.width
                plainText: file_caption
                color: pressed ? Theme.secondaryColor :Theme.primaryColor
                linkColor: pressed ? Theme.secondaryHighlightColor : Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: file_caption ? true : false
            }
        }
    }

    Component {
        id: stickerContent

        Column {
            width: stickerImage.width//messageListItem.width/4*3
            property int maxWidth: Screen.width-Theme.itemSizeExtraSmall - Theme.paddingMedium - 2*Theme.horizontalPageMargin

            Image {
                id:stickerImage
                asynchronous: true
                width: Math.min(implicitWidth,parent.maxWidth)
                height: width
                fillMode: Image.PreserveAspectFit
                source: content ? "image://depecherDb/" + content : ""
                MouseArea {
                    anchors.fill: parent
                    onClicked: pageStack.push(Qt.resolvedUrl("../components/PreviewStickerSetDialog.qml"),{set_id:sticker_set_id})
                }
            }
        }
    }

    Component {
        id: newMessageContent

        Item {
            width: messageListItem.width
            height: Theme.itemSizeSmall

            Rectangle {
                width: newMessagesLabel.width + 4*Theme.paddingLarge
                height: newMessagesLabel.height + 1*Theme.paddingLarge
                anchors.centerIn: parent
                radius: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.rgba(Theme.highlightBackgroundColor, 0.10) }
                    GradientStop { position: 1.0; color: Theme.rgba(Theme.highlightBackgroundColor, 0.30) }
                }

                Label {
                    id: newMessagesLabel
                    anchors.centerIn: parent
                    text: qsTr("New messages")
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: true
                }
            }
        }
    }

    Component {
        id:animationContent
        Column{
            width:animation.width
            Component {
                id:gifComponent
            AnimatedImage {
                id:animationGif
                property int maxWidth: Screen.width-Theme.itemSizeExtraSmall - Theme.paddingMedium - 2*Theme.horizontalPageMargin
                property int maxHeight: Screen.height/2
                width: photo_aspect > 1 ? maxWidth : maxHeight * photo_aspect
                height: photo_aspect > 1 ? maxWidth/photo_aspect : maxHeight
                fillMode: VideoOutput.PreserveAspectFit
                source: file_downloading_completed ? "file://"+content : ""
                playing: false
                Image {
                    id:animationThumbnail
                    anchors.fill: parent
                    source: "image://depecherDb/"+media_preview
                    visible:  mediaPlayer.playbackState != MediaPlayer.PlayingState || !file_downloading_completed;
                    Rectangle {
                        id:dimmedColor
                        anchors.fill: parent
                        opacity: 0.5
                        color:"black"
                    }
                    ProgressCircle {
                        id:progress
                        anchors.centerIn: parent

                        visible: file_is_uploading || file_is_downloading
                        value : file_is_uploading ? file_uploaded_size / file_downloaded_size :
                                                    file_downloaded_size / file_uploaded_size
                    }
                    Image {
                        id: downloadIcon
                        visible: !file_downloading_completed || progress.visible
                        source: progress.visible ? "image://theme/icon-s-clear-opaque-cross"
                                                 : "image://theme/icon-s-update"
                        anchors.centerIn: parent
                        MouseArea{
                            enabled: parent.visible
                            anchors.fill: parent
                            onClicked: {
                                if(progress.visible)
                                    if(file_is_downloading)
                                        messagingModel.cancelDownload(index)
                                    else
                                        messagingModel.deleteMessage(index)
                                else
                                    messagingModel.downloadDocument(index)
                            }
                        }
                    }
                    Label {
                        color:  Theme.primaryColor
                        visible: downloadIcon.visible
                        font.pixelSize: Theme.fontSizeTiny
                        text: Format.formatFileSize(file_downloaded_size) + "/"
                              + Format.formatFileSize(file_uploaded_size)
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: Theme.paddingSmall
                        anchors.bottomMargin: Theme.paddingSmall
                    }
                }
                Rectangle {
                    id:dimmedPlayColor
                    anchors.fill: animation
                    opacity: 0.5
                    color:"black"
                    visible: file_downloading_completed && mediaPlayer.playbackState != MediaPlayer.PlayingState

                }
                Image {
                    id: playIcon
                    visible: file_downloading_completed && mediaPlayer.playbackState != MediaPlayer.PlayingState
                    source:  "image://theme/icon-m-play"
                    anchors.centerIn: dimmedPlayColor
                }
                MouseArea{
                    anchors.fill: dimmedPlayColor
                    enabled: file_downloading_completed
                    onClicked: {
                        animationGif.playing = !animationGif.playing
                }
                    Connections {
                        target: Qt.application
                           onStateChanged: {
                              if(Qt.application.state !== Qt.ApplicationActive)
                                  nimationGif.playing = false
                           }
                    }

                }

            }
}
            Component {
                id:mp4Component
            VideoOutput {
                id: animation
                property int maxWidth: Screen.width-Theme.itemSizeExtraSmall - Theme.paddingMedium - 2*Theme.horizontalPageMargin
                property int maxHeight: Screen.height/2
                width: photo_aspect > 1 ? maxWidth : maxHeight * photo_aspect
                height: photo_aspect > 1 ? maxWidth/photo_aspect : maxHeight
                fillMode: VideoOutput.PreserveAspectFit

                source: MediaPlayer {
                    id: mediaPlayer
                    source: file_downloading_completed ? "file://"+(content) : ""
                    autoLoad: true
                    // autoPlay: true
                    loops:  Animation.Infinite
                }
                Connections {
                    target: Qt.application
                       onStateChanged: {
                          if(Qt.application.state !== Qt.ApplicationActive)
                              mediaPlayer.stop()
                       }
                }

                Image {
                    id:animationThumbnail
                    anchors.fill: parent
                    source: "image://depecherDb/"+media_preview
                    visible:  mediaPlayer.playbackState != MediaPlayer.PlayingState || !file_downloading_completed;
                    Rectangle {
                        id:dimmedColor
                        anchors.fill: parent
                        opacity: 0.5
                        color:"black"
                    }
                    ProgressCircle {
                        id:progress
                        anchors.centerIn: parent

                        visible: file_is_uploading || file_is_downloading
                        value : file_is_uploading ? file_uploaded_size / file_downloaded_size :
                                                    file_downloaded_size / file_uploaded_size
                    }
                    Image {
                        id: downloadIcon
                        visible: !file_downloading_completed || progress.visible
                        source: progress.visible ? "image://theme/icon-s-clear-opaque-cross"
                                                 : "image://theme/icon-s-update"
                        anchors.centerIn: parent
                        MouseArea{
                            enabled: parent.visible
                            anchors.fill: parent
                            onClicked: {
                                if(progress.visible)
                                    if(file_is_downloading)
                                        messagingModel.cancelDownload(index)
                                    else
                                        messagingModel.deleteMessage(index)
                                else
                                    messagingModel.downloadDocument(index)
                            }
                        }
                    }
                    Label {
                        color:  Theme.primaryColor
                        visible: downloadIcon.visible
                        font.pixelSize: Theme.fontSizeTiny
                        text: Format.formatFileSize(file_downloaded_size) + "/"
                              + Format.formatFileSize(file_uploaded_size)
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: Theme.paddingSmall
                        anchors.bottomMargin: Theme.paddingSmall
                    }
                }
                Rectangle {
                    id:dimmedPlayColor
                    anchors.fill: animation
                    opacity: 0.5
                    color:"black"
                    visible: file_downloading_completed && mediaPlayer.playbackState != MediaPlayer.PlayingState

                }
                Image {
                    id: playIcon
                    visible: file_downloading_completed && mediaPlayer.playbackState != MediaPlayer.PlayingState
                    source:  "image://theme/icon-m-play"
                    anchors.centerIn: dimmedPlayColor
                }
                MouseArea{
                    anchors.fill: dimmedPlayColor
                    enabled: file_downloading_completed
                    onClicked: {
                   mediaPlayer.playbackState != MediaPlayer.PlayingState ?   mediaPlayer.play() : mediaPlayer.stop()
                }
                }

            }
          }
            Loader {
                id:animation
                sourceComponent: file_type === "video/mp4" ? mp4Component : gifComponent
            }

            LinkedLabel {
                width: parent.width
                plainText:file_caption
                color: pressed ? Theme.secondaryColor :Theme.primaryColor
                linkColor: pressed ? Theme.secondaryHighlightColor :Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible:  file_caption === "" ? false : true
            }
        }
    }
}
