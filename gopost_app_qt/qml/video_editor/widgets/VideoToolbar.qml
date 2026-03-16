import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

/**
 * VideoToolbar — import/add tools bar with file picking, panel shortcuts.
 *
 * Converted 1:1 from video_toolbar.dart.
 */
Item {
    id: root
    height: 48

    property bool importing: false

    Rectangle {
        anchors.fill: parent
        color: "#1E1E38"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: "#303050"
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        // Initializing state
        RowLayout {
            visible: timelineNotifier.phase === 1 // initializing
            spacing: 8
            BusyIndicator { running: true; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
            Label { text: "Initializing..."; font.pixelSize: 12; color: "#8888A0" }
        }

        // Error state
        Button {
            visible: timelineNotifier.phase === 3 // error
            text: "Retry"
            icon.name: "view-refresh"
            onClicked: timelineNotifier.initTimeline()
        }

        // Ready state tools
        RowLayout {
            visible: timelineNotifier.isReady
            spacing: 0

            ToolBtn { iconText: "\uD83C\uDFA5"; label: "Video"; enabled: !importing; onClicked: videoDialog.open() }
            ToolBtn { iconText: "\uD83D\uDDBC"; label: "Photo"; enabled: !importing; onClicked: imageDialog.open() }

            // Separator
            Rectangle { width: 1; height: 28; color: "#303050"; Layout.leftMargin: 4; Layout.rightMargin: 4 }

            ToolBtn { iconText: "T"; label: "Text"; onClicked: internal.addTextClip() }

            Rectangle { width: 1; height: 28; color: "#303050"; Layout.leftMargin: 4; Layout.rightMargin: 4 }

            ToolBtn { iconText: "\u2728"; label: "Effects"; onClicked: timelineNotifier.setActivePanel(3) }   // effects
            ToolBtn { iconText: "\uD83C\uDFA8"; label: "Color"; onClicked: timelineNotifier.setActivePanel(4) } // colorGrading
            ToolBtn { iconText: "\u21C4"; label: "Transition"; onClicked: timelineNotifier.setActivePanel(5) }  // transitions
            ToolBtn { iconText: "\u23F1"; label: "Keyframe"; onClicked: timelineNotifier.setActivePanel(8) }    // keyframes
            ToolBtn { iconText: "\u266B"; label: "Audio"; onClicked: timelineNotifier.setActivePanel(9) }       // audio

            Rectangle { width: 1; height: 28; color: "#303050"; Layout.leftMargin: 4; Layout.rightMargin: 4 }

            ToolBtn { iconText: "+"; label: "Track"; onClicked: addTrackMenu.open() }
        }

        // Importing indicator
        RowLayout {
            visible: importing
            spacing: 6
            Layout.leftMargin: 8
            BusyIndicator { running: true; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
            Label { text: "Importing..."; font.pixelSize: 12; color: "#8888A0" }
        }

        Item { Layout.fillWidth: true }

        // Delete selected clip
        ToolBtn {
            visible: timelineNotifier.isReady && timelineNotifier.selectedClipId >= 0
            iconText: "\uD83D\uDDD1"
            label: "Delete"
            onClicked: timelineNotifier.removeClip(timelineNotifier.selectedClipId)
        }
    }

    // Add track popup menu
    Menu {
        id: addTrackMenu
        MenuItem { text: "Video Track"; onTriggered: timelineNotifier.addTrack(1) }
        MenuItem { text: "Audio Track"; onTriggered: timelineNotifier.addTrack(2) }
        MenuItem { text: "Title Track"; onTriggered: timelineNotifier.addTrack(3) }
        MenuItem { text: "Effect Track"; onTriggered: timelineNotifier.addTrack(0) }
    }

    // File dialogs
    FileDialog {
        id: videoDialog
        title: "Select Video"
        nameFilters: ["Video files (*.mp4 *.mov *.avi *.mkv *.webm *.m4v *.flv *.wmv *.3gp)"]
        onAccepted: internal.addClipFromFile(selectedFile, true)
    }

    FileDialog {
        id: imageDialog
        title: "Select Image"
        nameFilters: ["Image files (*.jpg *.jpeg *.png *.webp *.gif *.bmp *.heic *.tiff)"]
        onAccepted: internal.addClipFromFile(selectedFile, false)
    }

    QtObject {
        id: internal

        function addTextClip() {
            // Add a text clip to a title track (create one if needed)
            timelineNotifier.addTrack(3); // title
            var clipId = timelineNotifier.addClip(0, 3, "", "Text", 5.0);
            if (clipId >= 0) timelineNotifier.selectClip(clipId);
        }

        function addClipFromFile(fileUrl, isVideo) {
            root.importing = true;
            var path = fileUrl.toString().replace("file:///", "");
            var name = path.split("/").pop();
            var duration = isVideo ? 10.0 : 5.0;
            var sourceType = isVideo ? 0 : 1; // video=0, image=1
            var clipId = timelineNotifier.addClip(1, sourceType, path, name, duration);
            if (clipId >= 0 && isVideo) {
                timelineNotifier.generateProxyForClip(clipId);
            }
            root.importing = false;
        }
    }

    // Reusable tool button component
    component ToolBtn: Item {
        property string iconText: ""
        property string label: ""
        property bool enabled: true
        signal clicked()
        width: col.implicitWidth + 16
        height: 44
        Layout.leftMargin: 2; Layout.rightMargin: 2
        opacity: enabled ? 1.0 : 0.3

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 2
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: iconText
                font.pixelSize: 16
                color: "#E0E0F0"
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: label
                font.pixelSize: 9
                color: "#8888A0"
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
