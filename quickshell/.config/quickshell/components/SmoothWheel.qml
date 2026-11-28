import QtQuick
import qs.config

// Mouse wheel scrolling for a Flickable: each notch glides `step` pixels
// (Qt's own wheel moves 15 px per notch on Wayland), and notches in a row add
// up to where the glide is heading. Touchpads keep Qt's own scrolling
WheelHandler {
    id: root

    required property Flickable flickable
    // A notch used to glide 15 spacings; 24 makes the wheel cover the page
    // faster, and the shorter animation below makes it feel immediate
    property real step: Config.spacing * 24
    property int duration: Config.animDurationShort

    // Lets the owner stop its own scroll animation first
    signal wheelStarted

    function _clamp(y) {
        return Math.max(0, Math.min(flickable.contentHeight - flickable.height, y));
    }

    target: null
    // A mouse only: a touchpad's phased scrolling is left entirely to Qt's
    // Flickable, which follows the fingers and keeps its inertia. Taking those
    // events here (even to decline them) kept them from reaching the
    // Flickable, so two-finger scrolling did nothing at all.
    acceptedDevices: PointerDevice.Mouse
    onWheel: event => {
        // A phased event still arrives for a touchscreen or a device Qt does
        // not classify as a mouse: leave it to the Flickable
        if (event.phase !== Qt.NoScrollPhase || flickable.contentHeight <= flickable.height) {
            event.accepted = false;
            return;
        }
        root.wheelStarted();
        const from = glide.running ? glide.to : flickable.contentY;
        glide.to = _clamp(from - event.angleDelta.y / 120 * step);
        glide.restart();
    }

    property NumberAnimation _glide: NumberAnimation {
        id: glide

        target: root.flickable
        property: "contentY"
        duration: root.duration
        easing.type: Easing.OutCubic
    }
}
