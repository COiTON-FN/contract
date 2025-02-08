mod mods;
use mods::types::{User, UserType, Listing};
use starknet::ContractAddress;

#[starknet::interface]
pub trait ICoiton<TContractState> {
    //  USER SECTION
    fn register(ref self: TContractState, user_type: UserType, details: ByteArray);
    fn verify_user(ref self: TContractState, address: ContractAddress);
    fn get_user(self: @TContractState, address: ContractAddress) -> User;
    //  LISTING SECTION
    fn create_listing(ref self: TContractState, details: ByteArray);
    fn get_all_listings(self: @TContractState) -> Array<Listing>;
    fn get_listings_by_ids(self: @TContractState, ids: Array<u256>) -> Array<Listing>;
    //  TOKENS SECTION
    fn set_erc721(ref self: TContractState, address: ContractAddress);
    fn set_erc20(ref self: TContractState, address: ContractAddress);
    fn get_erc20(self: @TContractState) -> ContractAddress;
    fn get_erc721(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod Coiton {
    use super::mods::{
        types::{User, UserType, Listing}, errors::Errors,
        interfaces::{ierc721::{IERC721Dispatcher, IERC721DispatcherTrait}}
    };
    use starknet::{ContractAddress, storage::Map, get_caller_address};
    use core::num::traits::Zero;
    use openzeppelin_token::{erc20::interface::{ERC20ABISafeDispatcher, ERC20ABIDispatcherTrait},};


    #[storage]
    struct Storage {
        owner: ContractAddress,
        users_count: u256,
        user_id_pointer: Map::<u256, ContractAddress>,
        user: Map::<ContractAddress, User>,
        //  LISTING SECTIOIN
        listing_count: u256,
        listing: Map::<u256, Listing>,
        // TOKENS SECTION
        erc20: ContractAddress,
        erc721: ContractAddress
    }

    #[abi(embed_v0)]
    impl CoitonImpl of super::ICoiton<ContractState> {
        /// USER FUNCTIONS
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

        /// LISTING FUNCTIONS
        fn create_listing(ref self: ContractState, details: ByteArray) {
            let caller = get_caller_address();
            assert(self.user.read(caller).registered, Errors::NOT_REGISTERED);
            let id = self.listing_count.read() + 1;
            let new_listing = Listing { id, details, owner: caller };
            self.listing.write(id, new_listing);
            self.listing_count.write(id);
            let nft = IERC721Dispatcher { contract_address: self.erc721.read() };
            nft.safe_mint(caller, id, [].span());
        }

        fn get_all_listings(self: @ContractState) -> Array<Listing> {
            let mut index = 1;
            let mut listings = array![];
            let length = self.listing_count.read();
            while index <= length {
                listings.append(self.listing.read(index));
                index += 1;
            };
            listings
        }
        fn get_listings_by_ids(self: @ContractState, ids: Array<u256>) -> Array<Listing> {
            let mut listings = array![];
            for id in ids {
                listings.append(self.listing.read(id));
            };
            listings
        }

        // TOKENS SECTION
        fn set_erc721(ref self: ContractState, address: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
            assert(address.is_non_zero(), Errors::INVALID_ADDRESS);
            self.erc721.write(address);
        }
        fn set_erc20(ref self: ContractState, address: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
            assert(address.is_non_zero(), Errors::INVALID_ADDRESS);
            self.erc20.write(address);
        }
        fn get_erc20(self: @ContractState) -> ContractAddress {
            self.erc20.read()
        }
        fn get_erc721(self: @ContractState) -> ContractAddress {
            self.erc721.read()
        }
    }
}
