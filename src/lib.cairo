mod mods;
use mods::types::{User, UserType};
use starknet::ContractAddress;

#[starknet::interface]
pub trait ICoiton<TContractState> {
    fn register(ref self: TContractState, user_type: UserType, details: ByteArray);
    fn verify_user(ref self: TContractState, address: ContractAddress);
    fn get_user(self: @TContractState, address: ContractAddress) -> User;
}

#[starknet::contract]
mod Coiton {
    use super::mods::{types::{User, UserType}, errors::Errors};
    use starknet::{ContractAddress, storage::Map, get_caller_address};


    #[storage]
    struct Storage {
        owner: ContractAddress,
        users_count: u256,
        user_id_pointer: Map::<u256, ContractAddress>,
        user: Map::<ContractAddress, User>,
    }

    #[abi(embed_v0)]
    impl CoitonImpl of super::ICoiton<ContractState> {
        fn register(ref self: ContractState, user_type: UserType, details: ByteArray) {
            let caller = get_caller_address();
            assert(!self.user.read(caller).registered, Errors::ALREADY_EXIST);
            let id = self.users_count.read() + 1;
            let user = User {
                id, verified: false, details, user_type, address: caller, registered: true
            };
            self.user_id_pointer.write(id, caller);
            self.user.write(caller, user);
            self.users_count.write(id);
        }
        fn verify_user(ref self: ContractState, address: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
            let user = self.user.read(address);
            assert(user.registered, Errors::NOT_REGISTERED);
            self.user.write(address, User { verified: true, ..user });
        }
        fn get_user(self: @ContractState, address: ContractAddress) -> User {
            let user = self.user.read(address);
            assert(user.registered, Errors::NOT_REGISTERED);
            user
        }
    }
}
