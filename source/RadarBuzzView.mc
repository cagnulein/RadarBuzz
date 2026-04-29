using Toybox.AntPlus;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class RadarBuzzView extends WatchUi.DataField {

    hidden const DEFAULT_NEAR_THRESHOLD_METERS = 10.0;
    hidden const DEFAULT_MID_THRESHOLD_METERS = 25.0;

    hidden var mRadar;
    hidden var mRadarState;
    hidden var mDisplayText;
    hidden var mThreatCount;
    hidden var mNearestRange;
    hidden var mLastBuzzSecond;

    function initialize() {
        DataField.initialize();

        mRadar = new AntPlus.BikeRadar(null);
        mRadarState = AntPlus.DEVICE_STATE_CLOSED;
        mDisplayText = "PAIR";
        mThreatCount = 0;
        mNearestRange = null;
        mLastBuzzSecond = null;
    }

    function compute(info) {
        refreshRadarState();
        refreshDisplay(info);
        maybeBuzz();
    }

    function onUpdate(dc) {
        var bgColor = getBackgroundColor();
        var fgColor = bgColor == Graphics.COLOR_WHITE ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        dc.setColor(fgColor, bgColor);
        dc.clear();
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, mDisplayText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onTimerReset() {
        mLastBuzzSecond = null;
    }

    hidden function refreshRadarState() {
        var deviceState = mRadar.getDeviceState();
        if (deviceState == null || deviceState.state == null) {
            mRadarState = AntPlus.DEVICE_STATE_DEAD;
            return;
        }

        mRadarState = deviceState.state;
    }

    hidden function refreshDisplay(info) {
        mThreatCount = 0;
        mNearestRange = null;

        var radarInfo = mRadar.getRadarInfo() as Lang.Array<Toybox.AntPlus.RadarTarget>;
        if (radarInfo != null) {
            for (var i = 0; i < radarInfo.size(); i += 1) {
                var target = radarInfo[i];
                if (target == null || target.threat == 0) {
                    continue;
                }

                mThreatCount += 1;
                if (mNearestRange == null || target.range < mNearestRange) {
                    mNearestRange = target.range;
                }
            }
        }

        if (mRadarState == AntPlus.DEVICE_STATE_DEAD || mRadarState == AntPlus.DEVICE_STATE_CLOSED) {
            mDisplayText = "PAIR";
            return;
        }

        if (mRadarState == AntPlus.DEVICE_STATE_SEARCHING) {
            mDisplayText = "SCAN";
            return;
        }

        if (mThreatCount == 0 || mNearestRange == null) {
            mDisplayText = "CLEAR";
            return;
        }

        mDisplayText = mNearestRange.format("%.0fm") + " " + mThreatCount.format("%d");
    }

    hidden function maybeBuzz() {
        if (mThreatCount <= 0 || mNearestRange == null || !(Attention has :vibrate)) {
            if (mThreatCount <= 0) {
                mLastBuzzSecond = null;
            }
            return;
        }

        var now = System.getClockTime();
        var secondStamp = now.hour.format("%02d") + now.min.format("%02d") + now.sec.format("%02d");
        if (mLastBuzzSecond == secondStamp) {
            return;
        }

        try {
            Attention.vibrate(buildPattern(mNearestRange));
            mLastBuzzSecond = secondStamp;
        } catch (e) {
            mLastBuzzSecond = secondStamp;
        }
    }

    hidden function buildPattern(range) {
        var thresholds = getThresholds();

        if (range <= thresholds[:near]) {
            return [
                new Attention.VibeProfile(100, 220),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 220),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 220)
            ];
        }

        if (range <= thresholds[:mid]) {
            return [
                new Attention.VibeProfile(75, 260),
                new Attention.VibeProfile(0, 120),
                new Attention.VibeProfile(75, 260)
            ];
        }

        return [
            new Attention.VibeProfile(55, 350)
        ];
    }

    hidden function getThresholds() {
        var near = getNumericProperty("nearThresholdMeters", DEFAULT_NEAR_THRESHOLD_METERS);
        var mid = getNumericProperty("midThresholdMeters", DEFAULT_MID_THRESHOLD_METERS);

        if (near < 1.0) {
            near = DEFAULT_NEAR_THRESHOLD_METERS;
        }

        if (mid <= near) {
            mid = near + 1.0;
        }

        return {
            :near => near,
            :mid => mid
        };
    }

    hidden function getNumericProperty(key, fallback) {
        var value = Application.getApp().getProperty(key);
        if (value == null || !(value instanceof Lang.Number)) {
            return fallback;
        }

        return value.toFloat();
    }

}
