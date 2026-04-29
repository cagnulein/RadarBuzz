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
    hidden var mDebugTextTop;
    hidden var mDebugTextBottom;
    hidden var mThreatCount;
    hidden var mNearestRange;
    hidden var mLastBuzzSecond;
    hidden var mTimerRunning;

    function initialize() {
        DataField.initialize();

        mRadar = new AntPlus.BikeRadar(null);
        mRadarState = AntPlus.DEVICE_STATE_CLOSED;
        mDisplayText = "PAIR";
        mDebugTextTop = "S:-";
        mDebugTextBottom = "R:- T:-";
        mThreatCount = 0;
        mNearestRange = null;
        mLastBuzzSecond = null;
        mTimerRunning = false;
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
        dc.drawText(dc.getWidth() / 2, 6, Graphics.FONT_XTINY, mDebugTextTop, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, mDisplayText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - dc.getFontHeight(Graphics.FONT_XTINY) - 2, Graphics.FONT_XTINY, mDebugTextBottom, Graphics.TEXT_JUSTIFY_CENTER);
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
        var rawCount = 0;
        var firstRange = null;
        var firstThreat = null;
        if (radarInfo != null) {
            rawCount = radarInfo.size();
            for (var i = 0; i < radarInfo.size(); i += 1) {
                var target = radarInfo[i];
                if (i == 0 && target != null) {
                    firstRange = target.range;
                    firstThreat = target.threat;
                }
                if (target == null || target.threat == 0) {
                    continue;
                }

                mThreatCount += 1;
                if (mNearestRange == null || target.range < mNearestRange) {
                    mNearestRange = target.range;
                }
            }
        }

        mDebugTextTop = "S:" + formatState(mRadarState) + " R:" + rawCount.format("%d");
        mDebugTextBottom = "T:" + mThreatCount.format("%d") + " F:" + formatFirstTarget(firstRange, firstThreat);

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
        if (!mTimerRunning || mThreatCount <= 0 || mNearestRange == null || !(Attention has :vibrate)) {
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

    hidden function formatState(state) {
        if (state == AntPlus.DEVICE_STATE_DEAD) {
            return "DEAD";
        }
        if (state == AntPlus.DEVICE_STATE_CLOSED) {
            return "CLOSED";
        }
        if (state == AntPlus.DEVICE_STATE_SEARCHING) {
            return "SEARCH";
        }
        if (state == AntPlus.DEVICE_STATE_TRACKING) {
            return "TRACK";
        }
        if (state == null) {
            return "NULL";
        }

        return state.format("%d");
    }

    hidden function formatFirstTarget(firstRange, firstThreat) {
        if (firstRange == null && firstThreat == null) {
            return "-";
        }

        var rangeText = firstRange == null ? "?" : firstRange.format("%.0f");
        var threatText = firstThreat == null ? "?" : firstThreat.format("%d");
        return rangeText + "/" + threatText;
    }
}
