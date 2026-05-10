enum OrderActor { buyer, seller }

enum OrderAction {
  cancel,
  confirmMeetupPaid,
  markHandedOver,
  confirmReceived,
}

String orderStatusLabel(String status) {
  return switch (status) {
    'pending_payment' => 'Awaiting payment',
    'pending_meetup' => 'Pay on meetup',
    'awaiting_handoff' => 'Awaiting handoff',
    'handed_over' => 'Handed over',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status.replaceAll('_', ' '),
  };
}

Set<OrderAction> availableOrderActions({
  required OrderActor role,
  required String status,
}) {
  final actions = <OrderAction>{};

  if (role == OrderActor.buyer &&
      (status == 'pending_payment' || status == 'pending_meetup')) {
    actions.add(OrderAction.cancel);
  }

  if (role == OrderActor.seller && status == 'pending_meetup') {
    actions.add(OrderAction.confirmMeetupPaid);
  }

  if (role == OrderActor.seller && status == 'awaiting_handoff') {
    actions.add(OrderAction.markHandedOver);
  }

  if (role == OrderActor.buyer && status == 'handed_over') {
    actions.add(OrderAction.confirmReceived);
  }

  return actions;
}

