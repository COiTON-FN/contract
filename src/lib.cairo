pub mod mods;

#[starknet::contract]
pub mod Coiton {
    use openzeppelin_token::erc721::ERC721ABIDispatcherTrait;
    use openzeppelin_token::erc20::interface::ERC20ABISafeDispatcherTrait;
    use super::mods::{
        types::{User, UserType, Listing, PurchaseRequest, ListingTag, ListingType}, errors::Errors,
        events, interfaces::{ierc721::{IERC721Dispatcher, IERC721DispatcherTrait}, icoiton::ICoiton}
    };
    use starknet::{
        ContractAddress, ClassHash, SyscallResultTrait, storage::Map, get_caller_address,
        get_contract_address,
    };
    use core::{num::traits::Zero, panic_with_felt252};
    use openzeppelin_token::{
        erc20::interface::{ERC20ABISafeDispatcher}, erc721::interface::{ERC721ABIDispatcher}
    };
    const decimal: u256 = 18;


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
        version: u16,
        wallet: u256
    }

    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    // The event enum must be annotated with the `#[event]` attribute.
    // It must also derive at least the `Drop` and `starknet::Event` traits.
    pub enum Event {
        Upgrade: events::Upgrade,
        User: events::User,
        CreateListing: events::CreateListing,
        PurchaseRequest: events::PurchaseRequest,
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl CoitonImpl of ICoiton<ContractState> {
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
            self
                .emit(
                    Event::User(
                        events::User {
                            id, address: caller, event_type: events::UserEventType::Register
                        }
                    )
                )
        }
        fn verify_user(ref self: ContractState, address: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
            let user = self.user.read(address);
            assert(user.registered, Errors::NOT_REGISTERED);
            self.user.write(address, User { verified: true, ..user });
            self
                .emit(
                    Event::User(
                        events::User {
                            id: user.id,
                            address: get_caller_address(),
                            event_type: events::UserEventType::Verify
                        }
                    )
                )
        }
        fn get_user(self: @ContractState, address: ContractAddress) -> User {
            let user = self.user.read(address);
            assert(user.registered, Errors::NOT_REGISTERED);
            user
        }

        /// LISTING FUNCTIONS
        fn create_listing(
            ref self: ContractState, listing_type: ListingType, price: u256, details: ByteArray
        ) {
            let caller = get_caller_address();
            assert(self.user.read(caller).registered, Errors::NOT_REGISTERED);
            let id = self.listing_count.read() + 1;
            let new_listing = Listing {
                id,
                details,
                owner: caller,
                price,
                tag: ListingTag::ForSale,
                owner_details: Option::None,
                listing_type
            };
            self.listing.write(id, new_listing);
            self.listing_count.write(id);
            let nft = IERC721Dispatcher { contract_address: self.erc721.read() };
            nft.mint_coiton_nft(caller);
            self.emit(Event::CreateListing(events::CreateListing { id, owner: caller, price }))
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
                assert(_price >= listing.price, Errors::PRICE_TOO_LOW);
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
            self
                .emit(
                    Event::PurchaseRequest(
                        events::PurchaseRequest {
                            listing_id,
                            request_id,
                            bid_price,
                            initiator: caller,
                            request_type: events::PurchaseRequestType::Create
                        }
                    )
                )
        }

        fn approve_purchase_request(ref self: ContractState, listing_id: u256, request_id: u256) {
            let purchase_request = self.purchase_request.read((listing_id, request_id));
            let listing = self.listing.read(listing_id);
            let caller = get_caller_address();
            let contract = get_contract_address();
            assert(caller == listing.owner, Errors::UNAUTHORIZED);
            let nft = IERC721Dispatcher { contract_address: self.erc721.read() };
            assert(nft.get_approved(listing.id) == contract, Errors::INSUFFICIENT_ALLOWANCE);
            nft.transfer_from(listing.owner, caller, listing.id);
            let erc20 = ERC20ABISafeDispatcher { contract_address: self.erc20.read() };

            let fee = (listing.price * 2) / 100;
            let amount_to_send = listing.price - fee;

            erc20.transfer(listing.owner, amount_to_send).unwrap();
            self.wallet.write(self.wallet.read() + fee);
            self.listing.write(listing_id, Listing { tag: ListingTag::Sold, ..listing });

            /// REFUND BACK ANY OTHER PURCHASE REQUESTS
            let mut index = 1;
            let length = self.purchase_requests_count.read(listing_id);
            while index <= length {
                let _purchase_request = self.purchase_request.read((listing_id, index));
                if _purchase_request.initiator != purchase_request.initiator {
                    erc20.transfer(_purchase_request.initiator, _purchase_request.price).unwrap();
                }
                index += 1;
            };
            self
                .emit(
                    Event::PurchaseRequest(
                        events::PurchaseRequest {
                            listing_id,
                            request_id,
                            bid_price: Option::None,
                            initiator: caller,
                            request_type: events::PurchaseRequestType::Approve
                        }
                    )
                )
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
                let listing = self.listing.read(index);
                let listing_construct = Listing {
                    owner_details: Option::Some(self.get_user(listing.owner)), ..listing
                };
                listings.append(listing_construct);
                index += 1;
            };
            listings
        }
        fn get_user_listings(self: @ContractState, address: ContractAddress) -> Array<Listing> {
            let mut index = 1;
            let mut listings = array![];
            let length = self.listing_count.read();
            while index <= length {
                let user = self.get_user(address);
                let listing = self.listing.read(index);
                if listing.owner == address {
                    let listing_construct = Listing {
                        owner_details: Option::Some(user), ..listing
                    };
                    listings.append(listing_construct);
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
            let listing = self.listing.read(id);
            let listing_construct = Listing {
                owner_details: Option::Some(self.get_user(listing.owner)), ..listing
            };
            listing_construct
        }

        fn get_purchase(
            self: @ContractState, listing_id: u256, request_id: u256
        ) -> PurchaseRequest {
            self.purchase_request.read((listing_id, request_id))
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
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

        fn get_wallet_balance(self: @ContractState) -> u256 {
            self.wallet.read()
        }


        //  UTILITY FUNCTIONS
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(impl_hash.is_non_zero(), 'Class hash cannot be zero');
            assert(get_caller_address() == self.owner.read(), 'UNAUTHORIZED');
            starknet::syscalls::replace_class_syscall(impl_hash).unwrap_syscall();
            self.version.write(self.version.read() + 1);
            self.emit(Event::Upgrade(events::Upgrade { implementation: impl_hash }))
        }

        fn version(self: @ContractState) -> u16 {
            self.version.read()
        }


        fn withdraw(ref self: ContractState) {
            let owner = self.owner.read();
            assert(get_caller_address() == owner, Errors::UNAUTHORIZED);
            let wallet = self.wallet.read();
            assert(wallet > 0, 'ZERO_BALANCE');
            let erc20 = ERC20ABISafeDispatcher { contract_address: self.erc20.read() };
            erc20.transfer(owner, wallet).unwrap();
            self.wallet.write(0);
        }
    }
}
