import Hash "mo:base/Hash";

module {
    
    public type Company = {
        name: Text;
        desc: Text;
        webLink: Text;
        principal: Principal;
    };
    
    public type OrderStatus = {
        #open: Nat; // list tx id
        #cancel: Nat; // cancel tx id
        #done: Nat; // buy tx id
    };
    
    public type Order = {
        index: Nat;
        owner: Principal;
        var amount: Nat;
        var delta: Nat; //接受多少差价
        var price: Nat;
        var status: OrderStatus;
        createAt: Int;
    };

    public type ListArgs = {
        amount: Nat;
        price: Nat;
        delta: Nat;
    };

    public type UpdateArgs = {
        index: Nat;
        newAmount: Nat;
        newPrice: Nat;
        newDelta: Nat;
    };

    public type CancelArgs = {
        index: Nat;
    };

    public type Direction = {
        #Buy;
        #Sell;
    };

    public type Operation = {
        #deposit : {
            from: Principal;
            to: Principal;
            amount: Nat;
        };
        #withdraw : {
            from: Principal;
            to: Principal;
            amount: Nat;
        };
        #list : {
            orderId: Nat;
            user: Principal;
            price: Nat;
            amount: Nat;
            direction: Direction;
        };
        #cancel : {
            orderId: Nat;
            user: Principal;
            direction: Direction;
        };
        #deal : {
            orderId: Nat;
            seller: Principal;
            buyer: Principal;
            price: Nat;
            amount: Nat;
        };
    };

    public type OrderExt = {
        index: Nat;
        amount: Nat;
        owner: Principal;
        price: Nat; // can edit price after listing
        status: OrderStatus; // upadte to #done after order execution
        createAt: Int;
    };

    public func _hashOfOrder(
        order: Order
    ): Hash.Hash{
        Hash.hash(order.index)
    };

    public func _equalOfOrder(
        a: Order,b: Order
    ): Bool{
        a.index == b.index and a.price == b.price
    };
};    

