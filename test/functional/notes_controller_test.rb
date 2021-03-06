# def index
# def tools
# def places
# def shortlink
# def raw
# def show
# def create
# def edit
# def update
# def delete
# def author
# def author_topic
# def liked
# def popular
# def rss
# def liked_rss
# def rsvp

require 'test_helper'

class NotesControllerTest < ActionController::TestCase

  def setup
    activate_authlogic
  end

  test "redirect note short url" do
    note = DrupalNode.where(type: 'note', status: 1).last

    get :shortlink, id: note.id

    assert_redirected_to note.path
  end

  test "show note by id" do
    note = DrupalNode.where(type: 'note', status: 1).last
    assert_not_nil note.id

    get :show, id: note.id

    assert_response :success
  end

  test "show note" do
    note = DrupalNode.where(type: 'note', status: 1).last

    get :show,
        author: note.author.name,
        date: Time.at(note.created).strftime("%m-%d-%Y"),
        id: note.title.parameterize

    assert_response :success
  end

  test "don't show note by spam author" do
    note = node(:spam) # spam fixture

    get :show,
        author: note.author.name,
        date: Time.at(note.created).strftime("%m-%d-%Y"),
        id: note.title.parameterize

    assert_redirected_to '/'
  end

  test "should get index" do
    get :index

    assert_response :success
    assert_not_nil :notes
  end

  test "should get raw note markup" do
    id = DrupalNode.where(type: 'note', status: 1).last.id

    get :raw, id: id

    assert_response :success
  end

  test "should get tools" do
    get :tools

    assert_response :success
    assert_not_nil :notes
  end

  test "should get places" do
    get :places

    assert_response :success
    assert_not_nil :notes
  end

  test "post note no login" do
    # kind of weird, to successfully log out, we seem to have to first log in to get the UserSession...
    user_session = UserSession.create(rusers(:bob))
    user_session.destroy
    title = "My new post about balloon mapping"

    post :create,
         id: rusers(:bob).id,
         title: title,
         body: "This is a fascinating post about a balloon mapping event.",
         tags: "balloon-mapping,event"
         #, main_image: "/images/testimage.jpg"

    assert_redirected_to('/login')
  end

  test "non-first-timer posts note" do
    UserSession.create(rusers(:jeff))
    title = "My new post about balloon mapping"
    assert !rusers(:jeff).first_time_poster
    assert User.where(role: 'moderator').count > 0

    assert_difference 'ActionMailer::Base.deliveries.size', User.where(role: 'moderator').count do

      post :create,
           title: title,
           body:  "This is a fascinating post about a balloon mapping event.",
           tags:  "balloon-mapping,event"
           #, main_image: "/images/testimage.jpg"

    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "[PublicLab] " + title, email.subject
    assert_equal 1, DrupalNode.last.status
    assert_redirected_to "/notes/"+rusers(:jeff).username+"/"+Time.now.strftime("%m-%d-%Y")+"/"+title.parameterize
  end

  test "first-timer posts note" do
    UserSession.create(rusers(:lurker))
    title = "My first post to Public Lab"

    post :create,
         title: title,
         body: "This is a fascinating post about a balloon mapping event.",
         tags: "balloon-mapping,event"
         #, :main_image => "/images/testimage.jpg"

    assert_equal "Success! Thank you for contributing open research, and thanks for your patience while your post is approved by <a href='/wiki/moderation'>community moderators</a> and we'll email you when it is published. In the meantime, if you have more to contribute, feel free to do so.", flash[:notice]
    assert_nil flash[:warning] # no double notice
    assert_equal 4, DrupalNode.last.status
    assert_equal title, DrupalNode.last.title
    assert_redirected_to "/notes/"+rusers(:lurker).username+"/"+Time.now.strftime("%m-%d-%Y")+"/"+title.parameterize
  end

  test "first-timer moderated note (status=4) hidden to normal users on research note feed" do
    node = node(:first_timer_note)
    assert_equal 4, node.status

    get :index

    assert_select ".note-nid-#{node.id}", false
  end

  test "first-timer moderated note (status=4) hidden to normal users in full view" do
    node = node(:first_timer_note)
    assert_equal 4, node.status

    get :show,
        author: node.author.username,
        date: node.created_at.strftime("%m-%d-%Y"),
        id: node.title.parameterize

    assert_redirected_to "/"
  end

  test "first-timer moderated note (status=4) shown to author in full view with notice" do
    node = node(:first_timer_note)
    UserSession.create(node.author.user)
    assert_equal 4, node.status

    get :show,
        author: node.author.username,
        date: node.created_at.strftime("%m-%d-%Y"),
        id: node.title.parameterize

    assert_response :success
    assert_equal "Thank you for contributing open research, and thanks for your patience while your post is approved by <a href='/wiki/moderation'>community moderators</a> and we'll email you when it is published. In the meantime, if you have more to contribute, feel free to do so.", flash[:warning]
  end

  test "first-timer moderated note (status=4) shown to author in list view with notice" do
    node = node(:first_timer_note)
    UserSession.create(node.author.user)
    assert_equal 4, node.status

    get :index

    assert_response :success
    assert_select "div.note"
    assert_select "div.note-nid-#{node.nid} p.moderated", "Pending approval by community moderators. Please be patient!"
  end

  test "first-timer moderated note (status=4) shown to moderator with notice and approval prompt in full view" do
    UserSession.create(rusers(:moderator))
    node = node(:first_timer_note)
    assert_equal 4, node.status

    get :show,
        author: node.author.username,
        date: node.created_at.strftime("%m-%d-%Y"),
        id: node.title.parameterize

    assert_response :success
    assert_equal "First-time poster <a href='#{node.author.name}'>#{node.author.name}</a> submitted this #{time_ago_in_words(node.created_at)} ago and it has not yet been approved by a moderator. <a class='btn btn-default btn-sm' href='/moderate/publish/#{node.id}'>Approve</a> <a class='btn btn-default btn-sm' href='/moderate/spam/#{node.id}'>Spam</a>", flash[:warning]
  end

  test "first-timer moderated note (status=4) shown to moderator with notice and approval prompt in list view" do
    UserSession.create(rusers(:moderator))
    node = node(:first_timer_note)
    assert_equal 4, node.status

    get :index

    assert_response :success
    assert_select "div.note"
    assert_select "div.note-nid-#{node.nid} p.moderated", "Moderate first-time post: \n              Approve\n              Spam"
  end

  test "post_note_error_no_title" do
    UserSession.create(rusers(:bob))

    post :create,
         body: "This is a fascinating post about a balloon mapping event.",
         tags: "balloon-mapping,event"

    assert_template "editor/post"
    assert_select ".alert"
  end

  #def test_cannot_delete_post_if_not_yours

  #end

  test "edit note" do
    UserSession.create(rusers(:bob))
    title = "My second post about balloon mapping"

    post :create,
         title: title,
         body: "This is a fascinating post about a balloon mapping event.",
         tags: "balloon-mapping,event"
         #, main_image: "/images/testimage.jpg"

    assert_redirected_to "/notes/"+rusers(:bob).username+"/"+Time.now.strftime("%m-%d-%Y")+"/"+title.parameterize

    node = DrupalNode.where(title: title).first

    # add a tag, and change the title and body
    newtitle = title + " which I amended"

    post :update,
         id: node.id,
         title: newtitle,
         body: "This is a fascinating post about a balloon mapping event. <span id='teststring'>added content</span>",
         tags: "balloon-mapping,event,meetup"

    assert_redirected_to "/notes/" + rusers(:bob).username + "/" + Time.now.strftime("%m-%d-%Y") + "/" + title.parameterize + "?_=" + Time.now.to_i.to_s

    # approve the first-timer's note:
    node.publish

    get :show,
        author: rusers(:bob).username,
        date: Time.now.strftime("%m-%d-%Y"),
        id: title.parameterize

    assert_equal flash[:notice], "Edits saved."
    assert_select "h1", newtitle
    # assert_select "span#teststring", "added content" # this test does not work!! very frustrating.
    # assert_select ".label", "meetup" # test for tag addition too, later
  end

  test "should load iframe url in comments" do
    comment = DrupalComment.new({
      nid: node(:one).nid,
      uid: rusers(:bob).id,
      thread: "01/"
    })
    comment.comment = '<iframe src="http://mapknitter.org/embed/sattelite-imagery" style="border:0;"></iframe>'
    comment.save
    node = node(:one).path.split("/")

    get :show, id: node[4], author: node[2], date: node[3]

    assert_tag :tag => 'iframe', attributes: {src: 'http://mapknitter.org/embed/sattelite-imagery'}
  end

  # test "should mark admins and moderators with a special icon" do
  #   node = node(:one)
  #   get :show,
  #       author: node.author.username,
  #       date: node.created_at.strftime("%m-%d-%Y"),
  #       id: node.title.parameterize
  #   assert_select "i[title='Admin']", 1
  #   assert_select "i[title='Moderator']", 1
  # end

  test "should display an icon for users with streak longer than 7 days" do
    node = node(:one)
    User.any_instance.stubs(:note_streak).returns([8,10])
    User.any_instance.stubs(:wiki_edit_streak).returns([9,15])
    User.any_instance.stubs(:comment_streak).returns([10,30])
    get :show,
        author: node.author.username,
        date: node.created_at.strftime("%m-%d-%Y"),
        id: node.title.parameterize
    assert_select ".fa-fire", 3
  end

  test "should redirect to questions show page after creating a new question" do
    user = UserSession.create(rusers(:bob))
    title = "How to use a Spectrometer"
    post :create,
         title: title,
         body: "Spectrometer question",
         tags: "question:spectrometer",
         redirect: "question"

    assert_redirected_to "/questions/" + rusers(:bob).username + "/" + Time.now.strftime("%m-%d-%Y") + "/" + title.parameterize
  end

  test "should redirect to questions show page when editing an existing question" do
    user = UserSession.create(rusers(:jeff))
    note = node(:question)
    post :update,
         id: note.nid,
         title: note.title,
         body: "Spectrometer doubts",
         tags: "question:spectrometer",
         redirect: "question"

    assert_redirected_to note.path(:question) + "?_=" + Time.now.to_i.to_s
  end

  test "should assign correct value to graph_comments on GET stats" do
    DrupalComment.delete_all
    DrupalComment.create!({comment: 'blah', timestamp: Time.now() - 1})
    get :stats
    assert_equal assigns(:graph_comments), DrupalComment.comment_weekly_tallies(52, Time.now()).to_a.sort.to_json
  end

end
