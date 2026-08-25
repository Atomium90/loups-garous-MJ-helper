enum OrderRelation { after, before }

class OrderConstraint {
  final OrderRelation relation;
  final String roleId;

  const OrderConstraint.after(this.roleId) : relation = OrderRelation.after;
  const OrderConstraint.before(this.roleId) : relation = OrderRelation.before;
}
