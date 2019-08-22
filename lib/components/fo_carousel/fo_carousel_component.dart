// Copyright (c) 2017, Patrick. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as dom;

import 'package:angular/angular.dart';
import 'package:angular_components/material_radio/material_radio.dart';
import 'package:angular_components/material_radio/material_radio_group.dart';
import 'package:fo_components/components/fo_icon/fo_icon_component.dart';

import 'fo_carousel_slide_component.dart';

@Component(
    selector: 'fo-carousel',
    styleUrls: ['fo_carousel_component.css'],
    templateUrl: 'fo_carousel_component.html',
    directives: [
      FoIconComponent,
      FoCarouselSlideComponent,
      NgIf,
      MaterialRadioComponent,
      MaterialRadioGroupComponent,
      NgFor
    ],
    changeDetection: ChangeDetectionStrategy.OnPush)
class FoCarouselComponent implements OnDestroy, OnInit {
  final StreamController<int> _onStepController = StreamController();
  Timer timer;
  final ChangeDetectorRef _changeDetectorRef;

  void onTouchMove(dom.TouchEvent event) {
    if (disabled == true) {
      return;
    }

    final x = event.touches.first.screen.x;
    prevX ??= x;
    final delta = prevX - x;

    void disableWhileScrolling() {
      disabled = true;
      _scrollTimer = Timer(Duration(milliseconds: 200), () {
        disabled = false;
        _scrollTimer = null;
        prevX = null;
      });
    }

    if (delta < -20 && step > 0) {
      stepBy(-1);
      disableWhileScrolling();
    } else if (delta > 20 && step < slides.length - 1) {
      stepBy(1);
      disableWhileScrolling();
    } else {
      prevX = x;
    }
  }

  int prevX;
  Timer _scrollTimer;

  @Input()
  int step = 0;

  @Input()
  bool materialIcons = true;

  @Input()
  String nextIcon = 'keyboard_arrow_right';

  @Input()
  String prevIcon = 'keyboard_arrow_left';

  @Input()
  bool showRadioButtons = false;

  @Input()
  bool showArrowButtons = true;

  @Input()
  bool disabled = false;

  @Input()
  int duration;

  @ContentChildren(FoCarouselSlideComponent)
  List<FoCarouselSlideComponent> slides = [];

  FoCarouselComponent(this._changeDetectorRef);

  @Output('stepChange')
  Stream<int> get stepOutput => _onStepController.stream;

  String get transform => 'translate3d(${-step * 100}%, 0, 0)';

  @override
  void ngOnDestroy() {
    _onStepController.close();
    timer?.cancel();
    _scrollTimer?.cancel();
  }

  @override
  void ngOnInit() {
    if (duration != null) {
      timer =
          Timer.periodic(Duration(milliseconds: duration), (_) => stepBy(1));
    }
  }

  void onButtonChange(int slideNo, bool flag) {
    if (flag) {
      step = slideNo;
      _onStepController.add(step);

      timer?.cancel();
      if (duration != null) {
        timer = Timer(Duration(milliseconds: duration), () => stepBy(1));
      }
      _changeDetectorRef.markForCheck();
    }
  }

  void stepBy(int steps) {
    if (disabled != true) {
      step += steps;
      if (step >= slides.length || step < 0) {
        step = 0;
      }
      _onStepController.add(step);
      timer?.cancel();
      if (duration != null) {
        timer = Timer(Duration(milliseconds: duration), () => stepBy(1));
      }
      _changeDetectorRef.markForCheck();
    }
  }
}
