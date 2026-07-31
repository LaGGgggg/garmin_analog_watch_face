import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.Communications;


const VIEW_CIRCLE_PADDING = 15;
const CENTER_INNER_RADIUS = 3;
const CENTER_OUTER_RADIUS = 7;
const TICK_LENGTH = 5;
const ELLIPSE_HAND_ELLIPSE_OFFSET = 10;

const SECOND_HAND_LENGTH_PERCENT = 0.95;
const MINUTE_HAND_LENGTH_PERCENT = 0.85;
const HOUR_HAND_LENGTH_PERCENT = 0.75;

const SECOND_HAND_STROKE = 1;
const MINUTE_HAND_STROKE = 2;
const HOUR_HAND_STROKE = 2;

const MINUTE_HAND_ELLIPSE_MAJOR_RADIUS = 12;
const MINUTE_HAND_ELLIPSE_MINOR_RADIUS = 4;
const MINUTE_HAND_IS_FILLED = false;
const HOUR_HAND_ELLIPSE_MAJOR_RADIUS = 9;
const HOUR_HAND_ELLIPSE_MINOR_RADIUS = 3;
const HOUR_HAND_IS_FILLED = false;

const CALENDAR_EVENT_ARC_WIDTH = 2;
const CALENDAR_EVENT_ARC_RADIUS_PADDING = 2;
const CALENDAR_EVENT_COLORS = {
    "white"=>Graphics.COLOR_LT_GRAY,
    "green"=>Graphics.COLOR_DK_GREEN,
    "blue"=>Graphics.COLOR_BLUE,
    "orange"=>Graphics.COLOR_ORANGE,
};

const WIDGET_DATE_Y_OFFSET = 80;

const DAY_OF_WEEK_TO_STRING = {
    1=>"Sun",
    2=>"Mon",
    3=>"Tue",
    4=>"Wed",
    5=>"Thu",
    6=>"Fri",
    7=>"Sat",
};


class analogView extends WatchUi.WatchFace {

    var width;
    var height;

    var centerX;
    var centerY;

    var secondHandLength;
    var minuteHandLength;
    var hourHandLength;

    var tickRadius;

    var fontMain;

    var ellipseMinuteHandBitmap;
    var ellipseHourHandBitmap;

    var backgroundBitmap;

    var isInSleep = true;

    function initialize() {
        WatchFace.initialize();
    }

    function createEllipseBitmap(
        minorRadius as Number,
        majorRadius as Number,
        handStroke as Number,
        isFill as Boolean
    ) as Graphics.BufferedBitmapReference {

        var ellipseBitmap = Graphics.createBufferedBitmap({
            // 4 - padding
            :width=>majorRadius * 2 + 4,
            :height=>minorRadius * 2 + 4,
        });

        var bitmapDc = ellipseBitmap.get().getDc();

        bitmapDc.setColor(
            Graphics.COLOR_WHITE,
            Graphics.COLOR_TRANSPARENT
        );

        bitmapDc.setPenWidth(handStroke);

        if (isFill) {
            bitmapDc.fillEllipse(
                majorRadius,
                minorRadius,
                majorRadius,
                minorRadius
            );
        } else {
            bitmapDc.drawEllipse(
                majorRadius,
                minorRadius,
                majorRadius,
                minorRadius
            );
        }

        return ellipseBitmap;
    }

    function createBackgroundBitmap() as Graphics.BufferedBitmapReference {

        var backgroundBitmap = Graphics.createBufferedBitmap({
            :width=>self.width,
            :height=>self.height,
            :palette=>[
                Graphics.COLOR_TRANSPARENT,
                Graphics.COLOR_WHITE,
            ]
        });

        var bitmapDc = backgroundBitmap.get().getDc();

        bitmapDc.setColor(
            Graphics.COLOR_WHITE,
            Graphics.COLOR_TRANSPARENT
        );

        self.drawBackgroundTicks(bitmapDc);
        self.drawBackgroundCenter(bitmapDc);

        return backgroundBitmap;
    }

    function onLayout(dc as Dc) as Void {

        self.width = dc.getWidth();
        self.height = dc.getHeight();

        self.centerX = self.width / 2;
        self.centerY = self.height / 2;

        var smallerSideHalf = (self.width < self.height ? self.width : self.height) / 2;

        self.secondHandLength = smallerSideHalf * SECOND_HAND_LENGTH_PERCENT - VIEW_CIRCLE_PADDING;
        self.minuteHandLength = smallerSideHalf * MINUTE_HAND_LENGTH_PERCENT - VIEW_CIRCLE_PADDING;
        self.hourHandLength = smallerSideHalf * HOUR_HAND_LENGTH_PERCENT - VIEW_CIRCLE_PADDING;

        self.tickRadius = smallerSideHalf - VIEW_CIRCLE_PADDING / 2;

        self.fontMain = WatchUi.loadResource(Rez.Fonts.FiraCodeLight8Font);

        self.backgroundBitmap = self.createBackgroundBitmap();

        self.ellipseMinuteHandBitmap = self.createEllipseBitmap(
            MINUTE_HAND_ELLIPSE_MINOR_RADIUS,
            MINUTE_HAND_ELLIPSE_MAJOR_RADIUS,
            MINUTE_HAND_STROKE,
            MINUTE_HAND_IS_FILLED
        );
        self.ellipseHourHandBitmap = self.createEllipseBitmap(
            HOUR_HAND_ELLIPSE_MINOR_RADIUS,
            HOUR_HAND_ELLIPSE_MAJOR_RADIUS,
            HOUR_HAND_STROKE,
            HOUR_HAND_IS_FILLED
        );

        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    function drawLineHand(
        dc as Dc,
        divisionsNumber as Number,
        currentDivision,  // Number or Float
        length as Number,
        stroke as Number
    ) as Void {

      var angle = Math.toRadians(360 / divisionsNumber * currentDivision) - Math.PI / 2;

      var cos = Math.cos(angle);
      var sin = Math.sin(angle);

      var x2 = self.centerX + Math.round(cos * length);
      var y2 = self.centerY + Math.round(sin * length);

      var centerXWithOffset = self.centerX + Math.round(cos * CENTER_OUTER_RADIUS);
      var centerYWithOffset = self.centerY + Math.round(sin * CENTER_OUTER_RADIUS);

      dc.setPenWidth(stroke);
      dc.drawLine(centerXWithOffset, centerYWithOffset, x2, y2);
    }

    function drawEllipseHand(
        dc as Dc,
        divisionsNumber as Number,
        currentDivision,  // Number or Float
        length as Number,
        ellipseBitmap as Graphics.BufferedBitmapReference,
        minorRadius as Number,
        majorRadius as Number,
        stroke as Number
    ) as Void {

      var angle = Math.toRadians(360 / divisionsNumber * currentDivision) - Math.PI / 2;

      var cos = Math.cos(angle);
      var sin = Math.sin(angle);

      var innerLineLength = length - ELLIPSE_HAND_ELLIPSE_OFFSET - 2 * majorRadius;
      var ellipseCenterLength = innerLineLength + majorRadius;
      var outerLineStartLength = ellipseCenterLength + majorRadius;

      var xInner = self.centerX + Math.round(cos * innerLineLength);
      var yInner = self.centerY + Math.round(sin * innerLineLength);

      var ellipseCenterX = self.centerX + Math.round(cos * ellipseCenterLength);
      var ellipseCenterY = self.centerY + Math.round(sin * ellipseCenterLength);

      var xOuterLineStart = self.centerX + Math.round(cos * outerLineStartLength);
      var yOuterLineStart = self.centerY + Math.round(sin * outerLineStartLength);

      var xOuter = self.centerX + Math.round(cos * length);
      var yOuter = self.centerY + Math.round(sin * length);

      var centerXWithOffset = self.centerX + Math.round(cos * CENTER_OUTER_RADIUS);
      var centerYWithOffset = self.centerY + Math.round(sin * CENTER_OUTER_RADIUS);

      dc.setPenWidth(stroke);

      dc.drawLine(
          centerXWithOffset,
          centerYWithOffset,
          xInner,
          yInner
      );
      dc.drawLine(
          xOuterLineStart,
          yOuterLineStart,
          xOuter,
          yOuter
      );

      var bitmapTransform = new Graphics.AffineTransform();

      bitmapTransform.translate(majorRadius.toFloat(), minorRadius.toFloat());
      bitmapTransform.rotate(angle);
      bitmapTransform.translate(-majorRadius.toFloat(), -minorRadius.toFloat());

      dc.drawBitmap2(
          ellipseCenterX - majorRadius,
          ellipseCenterY - minorRadius,
          ellipseBitmap,
          {:transform=>bitmapTransform}
      );
    }

    function drawSecondHand(dc as Dc, clockTime as ClockTime) as Void {
        self.drawLineHand(dc, 60, clockTime.sec, self.secondHandLength, SECOND_HAND_STROKE);
    }

    function drawMinuteHand(dc as Dc, clockTime as ClockTime) as Void {
        self.drawEllipseHand(
            dc,
            60,
            clockTime.min,
            self.minuteHandLength,
            self.ellipseMinuteHandBitmap,
            MINUTE_HAND_ELLIPSE_MINOR_RADIUS,
            MINUTE_HAND_ELLIPSE_MAJOR_RADIUS,
            MINUTE_HAND_STROKE
        );
    }

    function drawHourHand(dc as Dc, clockTime as ClockTime) as Void {
        self.drawEllipseHand(
            dc,
            12,
            clockTime.hour + clockTime.min / 60.0,
            self.hourHandLength,
            self.ellipseHourHandBitmap,
            HOUR_HAND_ELLIPSE_MINOR_RADIUS,
            HOUR_HAND_ELLIPSE_MAJOR_RADIUS,
            HOUR_HAND_STROKE
        );
    }

    function drawBackgroundTicks(dc as Dc) as Void {
        for (var i = 0; i < 60; i += 5) {

            var angle = Math.toRadians(i * 6) - Math.PI / 2;

            var cos = Math.cos(angle);
            var sin = Math.sin(angle);

            var inner = self.tickRadius - TICK_LENGTH;
            var outer = self.tickRadius;

            var x1 = self.centerX + cos * inner;
            var y1 = self.centerY + sin * inner;

            var x2 = self.centerX + cos * outer;
            var y2 = self.centerY + sin * outer;

            dc.drawLine(x1, y1, x2, y2);
        }
    }

    function drawBackgroundCenter(dc as Dc) as Void {
        dc.fillCircle(self.centerX, self.centerY, CENTER_INNER_RADIUS);
        dc.drawCircle(self.centerX, self.centerY, CENTER_OUTER_RADIUS);
    }

    function zfill2(value as String) as String {
        switch (value.length()) {

            case 0:
                return "00";

            case 1:
                return "0" + value;

            default:
                return value;
        }
    }

    function drawWidgetDate(dc as Dc) as Void {

        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        var dateString = Lang.format(
            "$1$, $2$.$3$",
            [
                DAY_OF_WEEK_TO_STRING[today.day_of_week],
                self.zfill2(today.day.toString()),
                self.zfill2(today.month.toString()),
            ]
        );

        dc.drawText(
            self.centerX,
            self.centerY + WIDGET_DATE_Y_OFFSET,
            self.fontMain,
            dateString,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function convertTimestampToAngle(timestamp as Number) as Float {

        var info = Gregorian.info(new Time.Moment(timestamp), Time.FORMAT_SHORT);

        // 2 = 360 / (12 * 60)
        return 90.0 - ((info.hour % 12) * 60 + info.min) / 2.0;
    }

    function drawArcCalendarEvents(dc as Dc) as Void {

        var calendarEvents = (
            Application.Storage.getValue("calendarEvents") as Array<Lang.Dictionary> or Null
        );

        if (calendarEvents == null) { 
            return;
        }

        for (var i = 0; i < calendarEvents.size(); ++i) {

            var calendarEvent = calendarEvents[i];

            var end_timestamp_seconds = calendarEvent["end_timestamp_seconds"];

            // 43200 = 12 * 60 * 60
            if (end_timestamp_seconds > Time.now().value() + 43200) {
                continue;
            }

            var start_timestamp_seconds = calendarEvent["start_timestamp_seconds"];

            var eventColorRaw = calendarEvent["color"];
            var eventColor = Graphics.COLOR_WHITE;

            if (CALENDAR_EVENT_COLORS.hasKey(eventColorRaw)) {
                eventColor = CALENDAR_EVENT_COLORS[eventColorRaw];
            }

            dc.setColor(eventColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(CALENDAR_EVENT_ARC_WIDTH);

            dc.drawArc(
                self.centerX,
                self.centerY,
                self.tickRadius - CALENDAR_EVENT_ARC_RADIUS_PADDING,
                Graphics.ARC_CLOCKWISE,
                self.convertTimestampToAngle(start_timestamp_seconds),
                self.convertTimestampToAngle(end_timestamp_seconds)
            );
        }
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {

        View.onUpdate(dc);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        dc.drawBitmap(0, 0, self.backgroundBitmap);

        var clockTime = System.getClockTime();

        self.drawMinuteHand(dc, clockTime);
        self.drawHourHand(dc, clockTime);

        self.drawWidgetDate(dc);

        if (!self.isInSleep) {
            self.drawSecondHand(dc, clockTime);
        }

        self.drawArcCalendarEvents(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        self.isInSleep = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        self.isInSleep = true;
    }
}
