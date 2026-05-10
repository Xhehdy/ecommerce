import 'package:ecommerce/core/utils/order_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orderStatusLabel', () {
    test('pending payment label', () {
      expect(orderStatusLabel('pending_payment'), 'Awaiting payment');
    });

    test('pending meetup label', () {
      expect(orderStatusLabel('pending_meetup'), 'Pay on meetup');
    });

    test('awaiting handoff label', () {
      expect(orderStatusLabel('awaiting_handoff'), 'Awaiting handoff');
    });

    test('handed over label', () {
      expect(orderStatusLabel('handed_over'), 'Handed over');
    });

    test('completed label', () {
      expect(orderStatusLabel('completed'), 'Completed');
    });
  });

  group('availableOrderActions', () {
    test('buyer can cancel when pending_payment', () {
      expect(
        availableOrderActions(
          role: OrderActor.buyer,
          status: 'pending_payment',
        ),
        contains(OrderAction.cancel),
      );
    });

    test('buyer can cancel when pending_meetup', () {
      expect(
        availableOrderActions(
          role: OrderActor.buyer,
          status: 'pending_meetup',
        ),
        contains(OrderAction.cancel),
      );
    });

    test('seller can mark meetup paid when pending_meetup', () {
      expect(
        availableOrderActions(
          role: OrderActor.seller,
          status: 'pending_meetup',
        ),
        contains(OrderAction.confirmMeetupPaid),
      );
    });

    test('seller can mark handed over when awaiting_handoff', () {
      expect(
        availableOrderActions(
          role: OrderActor.seller,
          status: 'awaiting_handoff',
        ),
        contains(OrderAction.markHandedOver),
      );
    });

    test('buyer can confirm received when handed_over', () {
      expect(
        availableOrderActions(
          role: OrderActor.buyer,
          status: 'handed_over',
        ),
        contains(OrderAction.confirmReceived),
      );
    });
  });
}

