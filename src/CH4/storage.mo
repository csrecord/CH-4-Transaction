// transaction history storage canister

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Types "types";
import Date "./chronosphere/Date";

shared(msg) actor class Storage(_owner: Principal, _market: Principal) {
    /// Update call operations
    public type Operation = Types.Operation;
    /// Update call operation record fields
    public type OpRecord = Types.TxRecord;
    public type OrderStatus = Types.OrderStatus;
    public type PriceInfo = Types.PriceInfo;
    public type ItemInfo = Types.ItemInfo;

    public type OrderExt = {
        index: Nat;
        token: Principal; // token canister ID
        tokenIndex: Nat; // token index
        owner: Principal;
        price: Nat; // can edit price after listing
        status: OrderStatus; // upadte to #done after order execution
        createAt: Int;
    };

    private stable var owner_ : Principal = _owner;
    private stable var market_canister_id_ : Principal = _market;
    private stable var records: [OpRecord] = [];
    private stable var orders: [OrderExt] = [];
    private stable var currentTxIndex : Nat = 0;
    private stable var currentOrderIndex : Nat = 0;
    private var ops_acc = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
    private var orders_acc = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
    private var tokenOrders = HashMap.HashMap<Text, [Nat]>(1, Text.equal, Text.hash);
    private var collectionOrders = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
    private var collectionRecords = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
    
    private stable var opsAccEntries: [(Principal, [Nat])] = [];
    private stable var ordersAccEntries: [(Principal, [Nat])] = [];
    private stable var tokenOrderEntries: [(Text, [Nat])] = [];
    private stable var collectionOrderEntries: [(Principal, [Nat])] = [];
    private stable var collectionRecordEntries: [(Principal, [Nat])] = [];

    public shared(msg) func clearData() : async Bool {
        assert(msg.caller == owner_);
        ops_acc := HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
        return true;
    };

    public shared(msg) func setMarketCanisterId(token: Principal) : async Bool {
        assert(msg.caller == owner_);
        market_canister_id_ := token;
        return true;
    };

    private func _putOpsAcc(who: Principal, o: OpRecord) {
        switch (ops_acc.get(who)) {
            case (?op_acc) {
                var op_new : [Nat] = Array.append(op_acc, [o.index]);
                ops_acc.put(who, op_new);
            };
            case (_) {
                ops_acc.put(who, [o.index]);
            };
        }
    };

    private func _putOpsCollections(collection: Principal, txid: Nat) {
        switch (collectionRecords.get(collection)) {
            case (?cRecord) {
                var op_new : [Nat] = Array.append(cRecord, [txid]);
                collectionRecords.put(collection, op_new);
            };
            case (_) {
                collectionRecords.put(collection, [txid]);
            };
        }    
    };

    private func _putOrdsAcc(who: Principal, ord: OrderExt, idx: Nat) {
        switch (orders_acc.get(who)) {
            case (?ord_acc) {
                var ord_new : [Nat] = Array.append(ord_acc, [idx]);
                orders_acc.put(who, ord_new);
            };
            case (_) {
                orders_acc.put(who, [ord.index]);
            };
        }
    };

    private func _putTokenOrder(token: Principal, tokenIndex: Nat, orderIdx: Nat) {
        let key = Principal.toText(token) # ":" # Nat.toText(tokenIndex);
        switch (tokenOrders.get(key)) {
            case (?ords) {
                var ord_new : [Nat] = Array.append(ords, [orderIdx]);
                tokenOrders.put(key, ord_new);
            };
            case (_) {
                tokenOrders.put(key, [orderIdx]);
            };   
        }
    };

    private func _putCollectionOrder(token: Principal, orderIdx: Nat) {
        switch (collectionOrders.get(token)) {
            case (?ords) {
                var ord_new : [Nat] = Array.append(ords, [orderIdx]);
                collectionOrders.put(token, ord_new);
            };
            case (_) {
                collectionOrders.put(token, [orderIdx]);
            };   
        }
    };

    public shared(msg) func addRecord(caller: Principal, op: Operation, timestamp: Time.Time) : async Nat {
        assert(msg.caller == market_canister_id_);
        let o : OpRecord = {
            index = currentTxIndex;
            op = op;
            timestamp = timestamp;
        };
        currentTxIndex += 1;
        records := Array.append(records, [o]);
        _putOpsAcc(caller, o);
        switch (o.op) {
            case (#buy(b)) {
                _putOpsCollections(b.token, o.index);
            };
            case (_) {};
        };
        return o.index;
    };
  
    public shared(msg) func addOrder(order: OrderExt) : async Nat {
        assert(msg.caller == market_canister_id_);
        orders := Array.append(orders, [order]);
        _putOrdsAcc(order.owner, order, currentOrderIndex);
        switch(order.status) {
            case(#done(_)) {
                _putTokenOrder(order.token, order.tokenIndex, currentOrderIndex);
            };
            case(_) { };
        };
        switch(order.status) {
            case(#done(_)) {
                _putCollectionOrder(order.token, currentOrderIndex);
            };
            case(_) { };
        };
        currentOrderIndex += 1; // position in orders array
        return currentOrderIndex - 1;
    };

    public query func getTokenHistoryOrders(token: Principal, tokenIndex: Nat): async [OrderExt] {
        let key = Principal.toText(token) # ":" # Nat.toText(tokenIndex);
        switch (tokenOrders.get(key)) {
            case (?ordIdxs) {
                var ords = Buffer.Buffer<OrderExt>(ordIdxs.size());
                for(i in Iter.fromArray(ordIdxs)) {
                    ords.add(orders[i]);
                };
                ords.toArray()
            };
            case (_) {
                []
            };   
        }
    };

    public query func getCollectionHistoryOrders(token: Principal): async [OrderExt] {
        switch (collectionOrders.get(token)) {
            case (?ordIdxs) {
                var ords = Buffer.Buffer<OrderExt>(ordIdxs.size());
                for(i in Iter.fromArray(ordIdxs)) {
                    ords.add(orders[i]);
                };
                ords.toArray()
            };
            case (_) {
                []
            };   
        }
    };

    public query func getPriceHistory(collection: Principal, start: Int, end: Int): async [PriceInfo] {
        let _start = Date.stamp(start*1_000_000_000);
        let _end = Date.stamp(end*1_000_000_000);
        let _date_data = HashMap.HashMap<Date.Date, Buffer.Buffer<ItemInfo>>(1, Date.equal, Date.hash);
        let ret = Buffer.Buffer<PriceInfo>(8);
        let recordsIndex = switch (collectionRecords.get(collection)) {
            case (?records) { records };
            case (_) { return []; };
        };
        label l for (i in recordsIndex.vals()) {
            // require the array index == tx index
            let recordDate = Date.stamp(records[i].timestamp);
            if (Date.dateVal(recordDate) >= Date.dateVal(_start) and Date.dateVal(recordDate) <= Date.dateVal(_end)) {
                let txOp = switch (records[i].op) {
                    case (#buy(op)) { op };
                    case (_) { continue l;};
                };
                switch (_date_data.get(recordDate)) {
                    case (?dd) {
                        dd.add({
                            id = txOp.tokenIndex;
                            price = txOp.price;
                            from = txOp.seller;
                            to = txOp.buyer;
                            time = records[i].timestamp / 1_000_000_000;
                        });
                    };
                    case (_) {
                        let temp = Buffer.Buffer<ItemInfo>(8);
                        temp.add({
                            id = txOp.tokenIndex;
                            price = txOp.price;
                            from = txOp.seller;
                            to = txOp.buyer;
                            time = records[i].timestamp/1_000_000_000;
                        });
                        _date_data.put(recordDate, temp);
                    };
                };
            };
        };
        for (i in Date.iter(_start, _end)) {
            switch (_date_data.get(i)) {
                case (?a) {
                    var vol: Nat = 0;
                    var amount: Nat = 0;
                    var min: Nat = a.get(0).price;
                    var max: Nat = a.get(0).price;
                    for (j in a.vals()) {
                        vol += j.price;
                        amount += 1;
                        if (j.price > max) { max := j.price; };
                        if (j.price < min) { min := j.price; };
                    };
                    ret.add({
                        date = Date.toSec(i);
                        avg = vol / amount;
                        volume = vol;
                        num = amount;
                        min = min;
                        max = max;
                    });
                };
                case (_) {
                    ret.add({
                        date = Date.toSec(i);
                        avg = 0;
                        volume = 0;
                        num = 0;
                        min = 0;
                        max = 0;
                    });
                };
            };
        };
        ret.toArray()
    };

    public query func getItemHistory(collection: Principal, start: Int, end: Int): async [ItemInfo] {
        let _start = start*1_000_000_000;
        let _end = end*1_000_000_000;
        let ret = Buffer.Buffer<ItemInfo>(8);
        let recordsIndex = switch (collectionRecords.get(collection)) {
            case (?records) { records };
            case (_) { return []; };
        };
        label l for (i in recordsIndex.vals()) {
            // require the array index == tx index
            let recordTime = records[i].timestamp;
            if (recordTime >= _start and recordTime <= _end) {
                let txOp = switch (records[i].op) {
                    case (#buy(op)) { op };
                    case (_) { continue l;};
                };
                ret.add({
                    id = txOp.tokenIndex;
                    price = txOp.price;
                    from = txOp.seller;
                    to = txOp.buyer;
                    time = records[i].timestamp / 1_000_000_000;
                });
            };
        };
        ret.toArray()
    };

    /*** Tx history query functions ***/
    /// Get History by index.
    public query func getTransaction(index: Nat) : async OpRecord {
        return records[index];
    };
   
    /// Get history
    public query func getTransactions(start: Nat, num: Nat) : async [OpRecord] {
        var ret = Buffer.Buffer<OpRecord>(num);
        var i = start;
        while(i < start + num and i < records.size()) {
            ret.add(records[i]);
            i += 1;
        };
        return ret.toArray();
    };

    public query func getUserTransactionAmount(a: Principal) : async Nat {
        switch(ops_acc.get(a)) {
            case(?op_acc) { return op_acc.size(); };
            case(_) { return 0; };
        };
    };

    public query func getUserTransactions(a: Principal, start: Nat, num: Nat) : async [OpRecord] {
        let tx_indexs: [Nat] = switch (ops_acc.get(a)) {
            case (?op_acc) {
                op_acc
            };
            case (_) {
                []
            };
        };
        var ret = Buffer.Buffer<OpRecord>(num);
        var i = start;
        while(i < start + num and i < tx_indexs.size()) {
            ret.add(records[tx_indexs[i]]);
            i += 1;
        };
        return ret.toArray();
    };

    /*** Orders query functions ***/
    // user history orders
    public query func getUserOrderAmount(a: Principal): async Nat {
        let order_indexs: [Nat] = switch(orders_acc.get(a)) {
            case (?or_acc) {
                or_acc
            };
            case (_) {
                []
            };
        };
        return order_indexs.size()
    };

    // user partial history orders 
    public query func getUserOrders(a: Principal, start: Nat, num: Nat): async [OrderExt] {
        let order_indexs: [Nat] = switch (orders_acc.get(a)) {
            case (?or_acc) {
                or_acc
            };
            case (_) {
                []
            };
        };
        var ret = Buffer.Buffer<OrderExt>(num);
        var i = start;
        while(i < start + num and i < order_indexs.size()) {
            ret.add(orders[order_indexs[i]]);
            i += 1;
        };
        return ret.toArray();
    };
    
    /// Get all update call history.
    public query func allHistory() : async [OpRecord] {
        return records;
    };

    public query func marketCanisterId() : async Principal {
        return market_canister_id_;
    };

    public query func owner() : async Principal {
        return owner_;
    };

    public query func opAmount() : async Nat {
        return records.size();
    };

    public query func getCycles() : async Nat {
        return ExperimentalCycles.balance();
    };

    system func preupgrade() {
        opsAccEntries := Iter.toArray(ops_acc.entries());
        ordersAccEntries := Iter.toArray(orders_acc.entries());
        tokenOrderEntries := Iter.toArray(tokenOrders.entries());
        collectionOrderEntries := Iter.toArray(collectionOrders.entries());
        collectionRecordEntries := Iter.toArray(collectionRecords.entries());
    };

    system func postupgrade() {
        ops_acc := HashMap.fromIter<Principal, [Nat]>(opsAccEntries.vals(), 1, Principal.equal, Principal.hash);
        orders_acc := HashMap.fromIter<Principal, [Nat]>(ordersAccEntries.vals(), 1, Principal.equal, Principal.hash);
        collectionOrders := HashMap.fromIter<Principal, [Nat]>(collectionOrderEntries.vals(), 1, Principal.equal, Principal.hash);
        tokenOrders := HashMap.fromIter<Text, [Nat]>(tokenOrderEntries.vals(), 1, Text.equal, Text.hash);
        collectionRecords := HashMap.fromIter<Principal, [Nat]>(collectionRecordEntries.vals(), 1, Principal.equal, Principal.hash);
        opsAccEntries := [];
        ordersAccEntries := [];
        collectionOrderEntries := [];
        tokenOrderEntries := [];
        collectionRecordEntries := [];
    };
};
