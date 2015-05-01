# == Schema Information
#
# Table name: notes
#
#  id            :integer          not null, primary key
#  note          :text
#  noteable_type :string(255)
#  author_id     :integer
#  created_at    :datetime
#  updated_at    :datetime
#  project_id    :integer
#  attachment    :string(255)
#  line_code     :string(255)
#  commit_id     :string(255)
#  noteable_id   :integer
#  system        :boolean          default(FALSE), not null
#  st_diff       :text
#

require 'spec_helper'

describe Note do
  describe "Associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:noteable) }
    it { is_expected.to belong_to(:author).class_name('User') }
  end

  describe "Mass assignment" do
  end

  describe "Validation" do
    it { is_expected.to validate_presence_of(:note) }
    it { is_expected.to validate_presence_of(:project) }
  end

  describe 'voting score' do
    it 'recognizes a neutral note' do
      note = build(:votable_note, note: 'This is not a +1 note')
      expect(note).not_to be_upvote
      expect(note).not_to be_downvote
    end

    it 'recognizes a neutral emoji note' do
      note = build(:votable_note, note: "I would :+1: this, but I don't want to")
      expect(note).not_to be_upvote
      expect(note).not_to be_downvote
    end

    it 'recognizes a +1 note' do
      note = build(:votable_note, note: '+1 for this')
      expect(note).to be_upvote
    end

    it 'recognizes a +1 emoji as a vote' do
      note = build(:votable_note, note: ':+1: for this')
      expect(note).to be_upvote
    end

    it 'recognizes a thumbsup emoji as a vote' do
      note = build(:votable_note, note: ':thumbsup: for this')
      expect(note).to be_upvote
    end

    it 'recognizes a -1 note' do
      note = build(:votable_note, note: '-1 for this')
      expect(note).to be_downvote
    end

    it 'recognizes a -1 emoji as a vote' do
      note = build(:votable_note, note: ':-1: for this')
      expect(note).to be_downvote
    end

    it 'recognizes a thumbsdown emoji as a vote' do
      note = build(:votable_note, note: ':thumbsdown: for this')
      expect(note).to be_downvote
    end
  end

  let(:project) { create(:project) }

  describe "Commit notes" do
    let!(:note) { create(:note_on_commit, note: "+1 from me") }
    let!(:commit) { note.noteable }

    it "should be accessible through #noteable" do
      expect(note.commit_id).to eq(commit.id)
      expect(note.noteable).to be_a(Commit)
      expect(note.noteable).to eq(commit)
    end

    it "should save a valid note" do
      expect(note.commit_id).to eq(commit.id)
      note.noteable == commit
    end

    it "should be recognized by #for_commit?" do
      expect(note).to be_for_commit
    end

    it "should not be votable" do
      expect(note).not_to be_votable
    end
  end

  describe "Commit diff line notes" do
    let!(:note) { create(:note_on_commit_diff, note: "+1 from me") }
    let!(:commit) { note.noteable }

    it "should save a valid note" do
      expect(note.commit_id).to eq(commit.id)
      expect(note.noteable.id).to eq(commit.id)
    end

    it "should be recognized by #for_diff_line?" do
      expect(note).to be_for_diff_line
    end

    it "should be recognized by #for_commit_diff_line?" do
      expect(note).to be_for_commit_diff_line
    end

    it "should not be votable" do
      expect(note).not_to be_votable
    end
  end

  describe "Issue notes" do
    let!(:note) { create(:note_on_issue, note: "+1 from me") }

    it "should not be votable" do
      expect(note).to be_votable
    end
  end

  describe "Merge request notes" do
    let!(:note) { create(:note_on_merge_request, note: "+1 from me") }

    it "should be votable" do
      expect(note).to be_votable
    end
  end

  describe "Merge request diff line notes" do
    let!(:note) { create(:note_on_merge_request_diff, note: "+1 from me") }

    it "should not be votable" do
      expect(note).not_to be_votable
    end
  end

  describe '#create_cross_reference_note' do
    let(:project)    { create(:project) }
    let(:author)     { create(:user) }
    let(:issue)      { create(:issue, project: project) }
    let(:mergereq)   { create(:merge_request, :simple, target_project: project, source_project: project) }
    let(:commit)     { project.commit }

    # Test all of {issue, merge request, commit} in both the referenced and referencing
    # roles, to ensure that the correct information can be inferred from any argument.

    context 'issue from a merge request' do
      subject { Note.create_cross_reference_note(issue, mergereq, author) }

      it { is_expected.to be_valid }

      describe '#noteable' do
        subject { super().noteable }
        it { is_expected.to eq(issue) }
      end

      describe '#project' do
        subject { super().project }
        it { is_expected.to eq(issue.project) }
      end

      describe '#author' do
        subject { super().author }
        it { is_expected.to eq(author) }
      end

      describe '#note' do
        subject { super().note }
        it { is_expected.to eq("mentioned in merge request !#{mergereq.iid}") }
      end
    end

    context 'issue from a commit' do
      subject { Note.create_cross_reference_note(issue, commit, author) }

      it { is_expected.to be_valid }

      describe '#noteable' do
        subject { super().noteable }
        it { is_expected.to eq(issue) }
      end

      describe '#note' do
        subject { super().note }
        it { is_expected.to eq("mentioned in commit #{commit.sha}") }
      end
    end

    context 'merge request from an issue' do
      subject { Note.create_cross_reference_note(mergereq, issue, author) }

      it { is_expected.to be_valid }

      describe '#noteable' do
        subject { super().noteable }
        it { is_expected.to eq(mergereq) }
      end

      describe '#project' do
        subject { super().project }
        it { is_expected.to eq(mergereq.project) }
      end

      describe '#note' do
        subject { super().note }
        it { is_expected.to eq("mentioned in issue ##{issue.iid}") }
      end
    end

    context 'commit from a merge request' do
      subject { Note.create_cross_reference_note(commit, mergereq, author) }

      it { is_expected.to be_valid }

      describe '#noteable' do
        subject { super().noteable }
        it { is_expected.to eq(commit) }
      end

      describe '#project' do
        subject { super().project }
        it { is_expected.to eq(project) }
      end

      describe '#note' do
        subject { super().note }
        it { is_expected.to eq("mentioned in merge request !#{mergereq.iid}") }
      end
    end

    context 'commit contained in a merge request' do
      subject { Note.create_cross_reference_note(mergereq.commits.first, mergereq, author) }

      it { is_expected.to be_nil }
    end

    context 'commit from issue' do
      subject { Note.create_cross_reference_note(commit, issue, author) }

      it { is_expected.to be_valid }

      describe '#noteable_type' do
        subject { super().noteable_type }
        it { is_expected.to eq("Commit") }
      end

      describe '#noteable_id' do
        subject { super().noteable_id }
        it { is_expected.to be_nil }
      end

      describe '#commit_id' do
        subject { super().commit_id }
        it { is_expected.to eq(commit.id) }
      end

      describe '#note' do
        subject { super().note }
        it { is_expected.to eq("mentioned in issue ##{issue.iid}") }
      end
    end

    context 'commit from commit' do
      let(:parent_commit) { commit.parents.first }
      subject { Note.create_cross_reference_note(commit, parent_commit, author) }

      it { is_expected.to be_valid }

      describe '#noteable_type' do
        subject { super().noteable_type }
        it { is_expected.to eq("Commit") }
      end

      describe '#noteable_id' do
        subject { super().noteable_id }
        it { is_expected.to be_nil }
      end

      describe '#commit_id' do
        subject { super().commit_id }
        it { is_expected.to eq(commit.id) }
      end

      describe '#note' do
        subject { super().note }
        it { is_expected.to eq("mentioned in commit #{parent_commit.id}") }
      end
    end
  end

  describe '#system?' do
    let(:project) { create(:project) }
    let(:issue)   { create(:issue, project: project) }
    let(:other)   { create(:issue, project: project) }
    let(:author)  { create(:user) }
    let(:assignee) { create(:user) }
    let(:label) { create(:label) }
    let(:milestone) { create(:milestone) }

    it 'should recognize user-supplied notes as non-system' do
      @note = create(:note_on_issue)
      expect(@note).not_to be_system
    end

    it 'should identify cross-reference notes as system notes' do
      @note = Note.create_cross_reference_note(issue, other, author)
      expect(@note).to be_system
    end
  end

  describe :authorization do
    before do
      @p1 = create(:project)
      @p2 = create(:project)
      @u1 = create(:user)
      @u2 = create(:user)
      @u3 = create(:user)
      @abilities = Six.new
      @abilities << Ability
    end

    describe :read do
      before do
        @p1.project_members.create(user: @u2, access_level: ProjectMember::GUEST)
        @p2.project_members.create(user: @u3, access_level: ProjectMember::GUEST)
      end

      it { expect(@abilities.allowed?(@u1, :read_note, @p1)).to be_falsey }
      it { expect(@abilities.allowed?(@u2, :read_note, @p1)).to be_truthy }
      it { expect(@abilities.allowed?(@u3, :read_note, @p1)).to be_falsey }
    end

    describe :write do
      before do
        @p1.project_members.create(user: @u2, access_level: ProjectMember::DEVELOPER)
        @p2.project_members.create(user: @u3, access_level: ProjectMember::DEVELOPER)
      end

      it { expect(@abilities.allowed?(@u1, :write_note, @p1)).to be_falsey }
      it { expect(@abilities.allowed?(@u2, :write_note, @p1)).to be_truthy }
      it { expect(@abilities.allowed?(@u3, :write_note, @p1)).to be_falsey }
    end

    describe :admin do
      before do
        @p1.project_members.create(user: @u1, access_level: ProjectMember::REPORTER)
        @p1.project_members.create(user: @u2, access_level: ProjectMember::MASTER)
        @p2.project_members.create(user: @u3, access_level: ProjectMember::MASTER)
      end

      it { expect(@abilities.allowed?(@u1, :admin_note, @p1)).to be_falsey }
      it { expect(@abilities.allowed?(@u2, :admin_note, @p1)).to be_truthy }
      it { expect(@abilities.allowed?(@u3, :admin_note, @p1)).to be_falsey }
    end
  end

  it_behaves_like 'an editable mentionable' do
    subject { create :note, noteable: issue, project: project }

    let(:issue) { create :issue, project: project }
    let(:backref_text) { issue.gfm_reference }
    let(:set_mentionable_text) { ->(txt) { subject.note = txt } }
  end
end
