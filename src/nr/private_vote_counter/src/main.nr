use aztec::macros::aztec;

#[aztec]
pub contract PrivateVoteCounter {
    use aztec::{
        macros::{
            functions::{initializer, internal, private, public, utility},
            notes::note,
            storage::storage,
        },
        messages::logs::note::encode_and_encrypt_note,
        oracle::random::random,
        protocol_types::{address::AztecAddress, traits::Packable},
        state_vars::{Map, PrivateMutable, PublicMutable},
    };

    #[derive(Eq, Packable)]
    #[note]
    pub struct VoterBallot {
        voted: bool,
        voted_yes: bool,
        owner: AztecAddress,
        randomness: Field,
    }

    #[storage]
    pub struct Storage<Context> {
        // Public tallies - everyone can see the total
        yes_votes: PublicMutable<u128, Context>,
        no_votes: PublicMutable<u128, Context>,
        // Private vote records - only you know how you voted
        voter_ballots: Map<AztecAddress, PrivateMutable<VoterBallot, Context>, Context>,
    }

    #[initializer]
    #[public]
    fn constructor() {
        storage.yes_votes.write(0);
        storage.no_votes.write(0);
    }

    // Private function - your vote is secret
    #[private]
    fn cast_vote(vote_yes: bool) {
        let voter = context.msg_sender();

        let note = storage.voter_ballots.at(voter).get_note().note;
        assert(note.voted == false, "Voter has already voted");

        // Record that this voter has voted (privately)
        let ballot_note = VoterBallot {
            voted: true,
            voted_yes: vote_yes,
            owner: voter,
            // Safety: Using random oracle for note randomness
            randomness: unsafe { random() },
        };
        let _ = storage.voter_ballots.at(voter).replace(ballot_note).emit(encode_and_encrypt_note(
            &mut context,
            voter,
        ));

        // Enqueue public call to update the public tally
        if vote_yes {
            PrivateVoteCounter::at(context.this_address()).increment_yes().enqueue(&mut context);
        } else {
            PrivateVoteCounter::at(context.this_address()).increment_no().enqueue(&mut context);
        }
    }

    // Internal public functions - only callable from private functions
    #[public]
    #[internal]
    fn increment_yes() {
        let current = storage.yes_votes.read();
        storage.yes_votes.write(current + 1);
    }

    #[public]
    #[internal]
    fn increment_no() {
        let current = storage.no_votes.read();
        storage.no_votes.write(current + 1);
    }

    // Public view functions
    #[public]
    fn get_yes_votes() -> pub u128 {
        storage.yes_votes.read()
    }

    #[public]
    fn get_no_votes() -> pub u128 {
        storage.no_votes.read()
    }

    #[utility]
    unconstrained fn get_voter_ballot(voter: AztecAddress) -> pub VoterBallot {
        storage.voter_ballots.at(voter).view_note()
    }

}
