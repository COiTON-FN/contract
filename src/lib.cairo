mod mods;
use mods::types::{User, UserType, Listing, PurchaseRequest};
use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait ICoiton<TContractState> {
    //  USER SECTION
    fn register(ref self: TContractState, user_type: UserType, details: ByteArray);
    fn verify_user(ref self: TContractState, address: ContractAddress);
    fn get_user(self: @TContractState, address: ContractAddress) -> User;
    //  LISTING SECTION
    fn create_listing(ref self: TContractState, price: u256, details: ByteArray);
    fn get_all_listings(self: @TContractState) -> Array<Listing>;
    fn get_listings_by_ids(self: @TContractState, ids: Array<u256>) -> Array<Listing>;
    fn get_listing(self: @TContractState, id: u256) -> Listing;
    fn get_user_listings(self: @TContractState, address: ContractAddress) -> Array<Listing>;
    fn create_purchase_request(ref self: TContractState, listing_id: u256, bid_price: Option<u256>);
    fn approve_purchase_request(ref self: TContractState, listing_id: u256, request_id: u256);
    fn get_listings_with_purchase_requests(
        self: @TContractState, address: ContractAddress
    ) -> Array<Listing>;
    fn get_listing_purchase_requests(self: @TContractState, id: u256) -> Array<PurchaseRequest>;

    //  TOKENS SECTION
    fn set_erc721(ref self: TContractState, address: ContractAddress);
    fn set_erc20(ref self: TContractState, address: ContractAddress);
    fn get_erc20(self: @TContractState) -> ContractAddress;
    fn get_erc721(self: @TContractState) -> ContractAddress;

    // UTILITY FUNCTIONS
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
    fn version(self: @TContractState) -> u16;
}

#[starknet::contract]
mod Coiton {
    use openzeppelin_token::erc721::ERC721ABIDispatcherTrait;
    use openzeppelin_token::erc20::interface::ERC20ABISafeDispatcherTrait;
    use super::mods::{
        types::{User, UserType, Listing, PurchaseRequest, ListingTag}, errors::Errors,
        interfaces::{ierc721::{IERC721Dispatcher, IERC721DispatcherTrait}}
    };
    use starknet::{
        ContractAddress, ClassHash, SyscallResultTrait, storage::Map, get_caller_address,
        get_contract_address
    };
    use core::{num::traits::Zero, panic_with_felt252};
    use openzeppelin_token::{
        erc20::interface::{ERC20ABISafeDispatcher}, erc721::interface::{ERC721ABIDispatcher}
    };


    #[storage]
    struct Storage {
        owner: ContractAddress,
        users_count: u256,
        user_id_pointer: Map::<u256, ContractAddress>,
        user: Map::<ContractAddress, User>,
        //  LISTING SECTIOIN
        listing_count: u256,
        listing: Map::<u256, Listing>,
        purchase_requests_count: Map::<u256, u256>,
        purchase_request_pointer: Map::<(u256, ContractAddress), u256>,
        has_requested: Map::<ContractAddress, bool>,
        purchase_request: Map::<(u256, u256), PurchaseRequest>,
        request_notification_count: Map::<ContractAddress, u256>,
        request_notification_pointer: Map::<u256, u256>,
        // TOKENS SECTION
        erc20: ContractAddress,
        erc721: ContractAddress,
        // UTILITY SECTION
        version: u16
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
        fn create_listing(ref self: ContractState, price: u256, details: ByteArray) {
            let caller = get_caller_address();
            assert(self.user.read(caller).registered, Errors::NOT_REGISTERED);
            let id = self.listing_count.read() + 1;
            let new_listing = Listing {
                id, details, owner: caller, price, tag: ListingTag::ForSale
            };
            self.listing.write(id, new_listing);
            self.listing_count.write(id);
            let nft = IERC721Dispatcher { contract_address: self.erc721.read() };
            nft.safe_mint(caller, id, [].span());
        }

        fn create_purchase_request(
            ref self: ContractState, listing_id: u256, bid_price: Option<u256>
        ) {
            let listing = self.listing.read(listing_id);
            let caller = get_caller_address();
            let contract = get_contract_address();
            assert(listing.owner.is_non_zero(), Errors::INVALID_LISTING);
            if let ListingTag::Sold = listing.tag {
                panic_with_felt252(Errors::NOT_FOR_SALE);
            }
            assert(!self.has_requested.read(caller), Errors::ALREADY_EXIST);
            assert(listing.owner != caller, Errors::INVALID_PARAM);
            if let Option::Some(_price) = bid_price {
                assert(listing.price >= _price, Errors::PRICE_TOO_LOW);
            }
            let erc20 = ERC20ABISafeDispatcher { contract_address: self.erc20.read() };
            let price = if let Option::Some(_price) = bid_price {
                _price
            } else {
                listing.price
            };
            assert(
                erc20.allowance(caller, contract).unwrap() >= price, Errors::INSUFFICIENT_ALLOWANCE
            );
            erc20.transfer_from(caller, contract, price).unwrap();
            self.has_requested.write(caller, true);
            let request_id = self.purchase_requests_count.read(listing_id) + 1;
            let notification_index = self.request_notification_count.read(listing.owner) + 1;
            self.request_notification_count.write(listing.owner, notification_index);
            self.request_notification_pointer.write(notification_index, request_id);

            self
                .purchase_request
                .write(
                    (listing_id, request_id),
                    PurchaseRequest {
                        initiator: caller, request_id, listing_id, price, user: Option::None
                    }
                );
            self.purchase_requests_count.write(listing_id, request_id);
            self.purchase_request_pointer.write((request_id, listing.owner), listing_id);
        }

        fn approve_purchase_request(ref self: ContractState, listing_id: u256, request_id: u256) {
            let purchase_request = self.purchase_request.read((listing_id, request_id));
            let listing = self.listing.read(listing_id);
            let caller = get_caller_address();
            let contract = get_contract_address();
            assert(caller == listing.owner, Errors::UNAUTHORIZED);
            let nft = ERC721ABIDispatcher { contract_address: self.erc721.read() };
            assert(nft.get_approved(listing.id) == contract, Errors::INSUFFICIENT_ALLOWANCE);
            nft.transfer_from(caller, contract, listing.id);
            let erc20 = ERC20ABISafeDispatcher { contract_address: self.erc20.read() };
            erc20.transfer(listing.owner, purchase_request.price).unwrap();
            // TRANSFER NFT OWNERSHIP HERE

            self.listing.write(listing_id, Listing { tag: ListingTag::Sold, ..listing });

            /// REFUND BACK ANY OTHER PURCHASE REQUESTS
            let mut index = 1;
            let length = self.purchase_requests_count.read(listing_id) + 1;
            while index <= length {
                let _purchase_request = self.purchase_request.read((listing_id, index));
                if _purchase_request.initiator != purchase_request.initiator {
                    erc20.transfer(_purchase_request.initiator, _purchase_request.price).unwrap();
                }
                index += 1;
            };
        }

        fn get_listing_purchase_requests(self: @ContractState, id: u256) -> Array<PurchaseRequest> {
            let mut purchase_requests = array![];
            let mut index = 1;
            let length = self.purchase_requests_count.read(id) + 1;

            while index <= length {
                let purchase_request = self.purchase_request.read((id, index));
                purchase_requests
                    .append(
                        PurchaseRequest {
                            user: Option::Some(self.user.read(purchase_request.initiator)),
                            ..purchase_request
                        }
                    );
                index += 1;
            };

            purchase_requests
        }


        fn get_listings_with_purchase_requests(
            self: @ContractState, address: ContractAddress
        ) -> Array<Listing> {
            let mut listings = array![];
            let mut index = 1;
            let length = self.request_notification_count.read(address);
            while index <= length {
                let listing = self
                    .listing
                    .read(
                        self
                            .purchase_request_pointer
                            .read((self.request_notification_pointer.read(index), address))
                    );
                listings.append(listing);
                index += 1;
            };

            listings
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
        fn get_user_listings(self: @ContractState, address: ContractAddress) -> Array<Listing> {
            let mut index = 1;
            let mut listings = array![];
            let length = self.listing_count.read();
            while index <= length {
                let listing = self.listing.read(index);
                if listing.owner == address {
                    listings.append(listing);
                }
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

        fn get_listing(self: @ContractState, id: u256) -> Listing {
            self.listing.read(id)
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


        //  UTILITY FUNCTIONS
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(impl_hash.is_non_zero(), 'Class hash cannot be zero');
            assert(get_caller_address() == self.owner.read(), 'UNAUTHORIZED');
            starknet::syscalls::replace_class_syscall(impl_hash).unwrap_syscall();
            self.version.write(self.version.read() + 1);
            // self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }))
        }

        fn version(self: @ContractState) -> u16 {
            self.version.read()
        }
    }
}
