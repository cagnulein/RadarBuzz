using Toybox.AntPlus;
using Toybox.Activity;
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
    hidden var mDebugCompactText;
    hidden var mThreatCount;
    hidden var mNearestRange;
    hidden var mLastBuzzSecond;
    hidden var mLastVibeResult;
    hidden var mTimerRunning;

    function initialize() {
        DataField.initialize();

        mRadar = new AntPlus.BikeRadar(null);
        mRadarState = AntPlus.DEVICE_STATE_CLOSED;
        mDisplayText = "PAIR";
        mDebugCompactText = "S:- R:- T:-";
        mThreatCount = 0;
        mNearestRange = null;
        mLastBuzzSecond = null;
        mLastVibeResult = "V-";
        mTimerRunning = false;
    }

    function compute(info) {
        mTimerRunning = info != null && info.timerState == Activity.TIMER_STATE_ON;
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

    function onTimerStart() {
        mTimerRunning = true;
    }

    function onTimerResume() {
        mTimerRunning = true;
    }

    function onTimerPause() {
        mTimerRunning = false;
        mLastBuzzSecond = null;
    }

    function onTimerStop() {
        mTimerRunning = false;
        mLastBuzzSecond = null;
    }

    function onTimerReset() {
        mTimerRunning = false;
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

        mDebugCompactText = "A" + (mTimerRunning ? "1" : "0") + " " + mLastVibeResult;

        if (mRadarState == AntPlus.DEVICE_STATE_DEAD || mRadarState == AntPlus.DEVICE_STATE_CLOSED) {
            mDisplayText = "PAIR " + mDebugCompactText;
            return;
        }

        if (mRadarState == AntPlus.DEVICE_STATE_SEARCHING) {
            mDisplayText = "SCAN " + mDebugCompactText;
            return;
        }

        if (mThreatCount == 0 || mNearestRange == null) {
            mDisplayText = "CLEAR " + mDebugCompactText;
            return;
        }

        mDisplayText = mNearestRange.format("%.0fm") + " " + mThreatCount.format("%d") + " " + mDebugCompactText;
    }

    hidden function maybeBuzz() {
        if (!mTimerRunning || mThreatCount <= 0 || mNearestRange == null || !(Attention has :vibrate)) {
            if (mThreatCount <= 0) {
                mLastBuzzSecond = null;
            }
            if (!(Attention has :vibrate)) {
                mLastVibeResult = "VNA";
            } else if (!mTimerRunning) {
                mLastVibeResult = "VPA";
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
            mLastVibeResult = "VOK";
        } catch (e) {
            mLastBuzzSecond = secondStamp;
            mLastVibeResult = "VER";
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
