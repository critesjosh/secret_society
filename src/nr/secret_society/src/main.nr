use aztec::macros::aztec;

#[aztec]
pub contract SecretSociety {
    use address_note::address_note::AddressNote;
    use aztec::{
        macros::{
            functions::{initializer, internal, private, public},
            notes::note,
            storage::storage,
        },
        messages::logs::note::encode_and_encrypt_note,
        protocol_types::address::AztecAddress,
        state_vars::{Map, PrivateSet, PublicMutable},
    };

    #[storage]
    pub struct Storage<Context> {
        // Public admin - visible to all
        admin: PublicMutable<AztecAddress, Context>,
        // Private sets - membership is secret
        moderators: PrivateSet<AddressNote, Context>,
        is_moderator: Map<AztecAddress, PublicMutable<bool, Context>, Context>,
        members: PrivateSet<AddressNote, Context>,
    }

    #[initializer]
    #[public]
    fn constructor(admin_address: AztecAddress) {
        storage.admin.write(admin_address);
    }

    #[private]
    fn add_moderator(moderator: AztecAddress, randomness: Field) {
        let _ = storage.moderators.insert(AddressNote::new(moderator, moderator)).emit(
            encode_and_encrypt_note(&mut context, moderator),
        );

        SecretSociety::at(context.this_address())._verify_admin(context.msg_sender()).enqueue(
            &mut context,
        );
    }

    #[private]
    fn add_member(member: AztecAddress) {
        let _ = storage.members.insert(AddressNote::new(member, member)).emit(
            encode_and_encrypt_note(&mut context, member),
        );

        SecretSociety::at(context.this_address())._verify_moderator(context.msg_sender()).enqueue(
            &mut context,
        );
    }

    #[public]
    #[internal]
    fn _verify_moderator(sender: AztecAddress) {
        assert(storage.is_moderator.at(sender).read(), "Sender is not a moderator");
    }

    #[public]
    #[internal]
    fn _verify_admin(sender: AztecAddress) {
        assert(sender == storage.admin.read(), "Sender is not the admin");
    }

    #[public]
    fn get_admin() -> pub AztecAddress {
        storage.admin.read()
    }

}
