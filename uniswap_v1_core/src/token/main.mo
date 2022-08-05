import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";

actor ERC20Token {
    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    private var allowances  = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat>>(1, Principal.equal, Principal.hash);

    public shared({caller}) func transfer(_to : Principal, _value : Nat) : async Bool {
        switch(balances.get(caller)){
            case(?from_balance){
                if(from_balance >= _value){
                    var from_balance_new = from_balance - _value;
                    var to_balance_new = switch (balances.get(_to)) {
                        case (?to_balance) {
                            to_balance + _value;
                        };
                        case (_) {
                            _value;
                        };
                    };
                    assert(from_balance_new <= from_balance);
                    assert(to_balance_new >= _value);
                    balances.put(caller, from_balance_new);
                    balances.put(_to, to_balance_new);
                    return true;
                }else{
                    return false;
                }
            };
            case(_){
                return false;
            };
        };
    };


    public shared({caller}) func transferFrom(_from : Principal, _to : Principal, _value : Nat) : async Bool {
        switch (balances.get(_from), allowances.get(_from)) {
            case (?from_balance, ?allowance_from) {
                switch (allowance_from.get(caller)) {
                    case (?allowance) {
                        if (from_balance >= _value and allowance >= _value) {
                            var from_balance_new = from_balance - _value;
                            var allowance_new = allowance - _value;
                            var to_balance_new = switch (balances.get(_to)) {
                                case (?to_balance) {
                                    to_balance + _value;
                                };
                                case (_) {
                                    _value;
                                };
                            };
                            assert(from_balance_new <= from_balance);
                            assert(to_balance_new >= _value);
                            allowance_from.put(caller, allowance_new);
                            allowances.put(_from, allowance_from);
                            balances.put(_from, from_balance_new);
                            balances.put(_to, to_balance_new);
                            return true;                            
                        } else {
                            return false;
                        };
                    };
                    case (_) {
                        return false;
                    };
                }
            };
            case (_) {
                return false;
            };
        }
    };

    public shared({caller}) func approve(_spender: Principal, _value: Nat) : async Bool {
        switch(allowances.get(caller)) {
            case (?allowances_caller) {
                allowances_caller.put(_spender, _value);
                allowances.put(caller, allowances_caller);
                return true;
            };
            case (_) {
                var temp = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
                temp.put(_spender, _value);
                allowances.put(caller, temp);
                return true;
            };
        }
    };

    public query func balanceOf(_who: Principal) : async Nat {
        switch (balances.get(_who)) {
            case (?balance) {
                return balance;
            };
            case (_) {
                return 0;
            };
        }
    };

    public query func allowance(_owner: Principal, _spender: Principal) : async Nat {
        switch(allowances.get(_owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(_spender)) {
                    case (?allowance) {
                        return allowance;
                    };
                    case (_) {
                        return 0;
                    };
                }
            };
            case (_) {
                return 0;
            };
        }
    };
}