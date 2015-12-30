require 'rails_helper'

RSpec.describe Api::ProjectsController, type: :controller do
  let(:student) {FactoryGirl.create(:student)}
  let(:unpublished_course) {FactoryGirl.create(:course)}
  let(:published_course) {FactoryGirl.create(:course, published: true)}
  let(:teacher) {FactoryGirl.create(:teacher)}
  describe "index" do
    let(:projects) {FactoryGirl.create_list(:project, 3, course: published_course)}
    let(:published_projects) {FactoryGirl.create_list(:project, 2, course: published_course, published: true)}
    it 'disallow unauthorized' do
      get :index, format: :json, course_id: published_course.id
      expect(response).to be_unauthorized
    end
    it 'allow a student to index' do
      set_token student.token
      get :index, format: :json, course_id: published_course.id
      expect(response).to be_success
    end
    it 'allow a teacher to index' do
      set_token teacher.token
      get :index, format: :json, course_id: published_course.id
      expect(response).to be_success
    end
    it 'have pagination' do
      set_token teacher.token
      get :index, format: :json, course_id: published_course.id
      expect(json_response).to include(
        :projects, :page, :page_size, :total_pages
        )
    end
    it 'not return unpublished projects to students' do
      projects
      set_token student.token
      get :index, format: :json, course_id: published_course.id
      expect(json_response[:page_size]).to eql 0
    end
    it 'disallow a student to index projects of an unpublished course' do
      projects = FactoryGirl.create(:project, course: unpublished_course)
      set_token student.token
      get :index, format: :json, course_id: unpublished_course.id
      expect(json_response).to_not include(:projects)
      expect(response).to be_forbidden
    end
    it 'allow a teacher to index projects of a published course' do
      projects = FactoryGirl.create(:project, course: unpublished_course)
      set_token teacher.token
      get :index, format: :json, course_id: unpublished_course.id
      expect(json_response).to include(:projects)
      expect(response).to be_success
    end
    context 'query' do
      it 'override published param for students' do
        projects
        set_token student.token
        get :index, format: :json, course_id: published_course.id, published: false
        expect(json_response[:page_size]).to eql 0
      end
      it 'by published' do
        published_projects
        projects
        set_token teacher.token
        get :index, format: :json, course_id: published_course.id, published: true
        expect(json_response[:page_size]).to eql published_projects.size
      end
      it 'not set default published param for teachers' do
        projects
        set_token teacher.token
        get :index, format: :json, course_id: published_course.id
        expect(json_response[:page_size]).to eql projects.size
      end
      it 'by name' do
        project = FactoryGirl.create(:project, course: published_course, name: 'stupid name')
        set_token teacher.token
        get :index, format: :json, course_id: published_course.id, name: project.name
        expect(json_response[:page_size]).to eql 1
      end

      it 'by started' do
        project = FactoryGirl.create(:project, course: published_course, start_date: 3.days.ago, published: true)
        FactoryGirl.create(:project, course: published_course, start_date: 5.days.from_now, published: true)
        set_token student.token
        get :index, format: :json, course_id: published_course.id, started: true
        expect(json_response[:page_size]).to eql 1
        expect(json_response[:projects].first[:id]).to eql project.id
      end
    end
  end
  describe 'show' do
    let(:published_project_published_course) {FactoryGirl.create(:project, course: published_course, published: true)}
    let(:unpublished_project_published_course) {FactoryGirl.create(:project, course: published_course, published: false)}
    let(:published_project_unpublished_course) {FactoryGirl.create(:project, course: unpublished_course, published: true)}
    let(:unpublished_project_unpublished_course) {FactoryGirl.create(:project, course: unpublished_course, published: false)}
    it 'disallow unauthorized' do
      get :show, format: :json, id: published_project_published_course.id
      expect(response).to be_unauthorized
    end
    it 'disallow a student to view a published project of an unpublished course' do
      set_token student.token
      get :show, format: :json, id: published_project_unpublished_course.id
      expect(response).to be_forbidden
    end
    it 'disallow a student to view an unpublished project of an unpublished course' do
      set_token student.token
      get :show, format: :json, id: unpublished_project_unpublished_course.id
      expect(response).to be_forbidden
    end

    it 'disallow a student to view an unpublished project of a published course' do
      set_token student.token
      get :show, format: :json, id: unpublished_project_published_course.id
      expect(response).to be_forbidden
    end

    it 'allow a teacher to view a published project of an unpublished course' do
      set_token teacher.token
      get :show, format: :json, id: published_project_unpublished_course.id
      expect(response).to be_success
      expect(json_response[:id]).to eql published_project_unpublished_course.id
    end
    it 'allow a teacher to view an unpublished project of an unpublished course' do
      set_token teacher.token
      get :show, format: :json, id: unpublished_project_unpublished_course.id
      expect(response).to be_success
      expect(json_response[:id]).to eql unpublished_project_unpublished_course.id
    end

    it 'allow a student to view a published project of a published course' do
      set_token student.token
      get :show, format: :json, id: published_project_published_course.id
      expect(response).to be_success
      expect(json_response[:id]).to eql published_project_published_course.id
    end

    it 'allow teacher to view a published project of a published course' do
      set_token teacher.token
      get :show, format: :json, id: published_project_published_course.id
      expect(response).to be_success
      expect(json_response[:id]).to eql published_project_published_course.id
    end

    it 'allow a teacher to view an unpublished project of a published course' do
      set_token teacher.token
      get :show, format: :json, id: unpublished_project_published_course.id
      expect(response).to be_success
      expect(json_response[:id]).to eql unpublished_project_published_course.id
    end
  end
  describe "create" do
    let(:params) {FactoryGirl.attributes_for(:project)}
    it 'disallow unauthorized' do
      expect {
        post :create, format: :json, course_id: published_course.id, **params
      }.to change(Project, :count).by 0
      expect(response).to be_unauthorized
    end
    it 'disallow student' do
      expect {
        set_token student.token
        post :create, format: :json, course_id: published_course.id, **params
      }.to change(Project, :count).by 0
      expect(response).to be_forbidden
    end
    it 'allow teacher' do
      expect {
        set_token teacher.token
        post :create, format: :json, course_id: published_course.id, **params
      }.to change(Project, :count).by 1
      expect(response).to be_created
      expect(json_response[:course_id]).to eql published_course.id
    end
  end
  describe "update" do
    let(:project) {FactoryGirl.create(:project, published: true, course: published_course)}
    
    it 'disallow unauthorized' do
      project.reload
      original = project.as_json
      put :update, format: :json, id: project.id, quiz: true
      expect(response).to be_unauthorized
      project.reload
      expect(original).to eql project.as_json
    end
    
    it 'disallow student' do
      project.reload
      set_token student.token
      original = project.as_json
      put :update, format: :json, id: project.id, quiz: true
      expect(response).to be_forbidden
      project.reload
      expect(original).to eql project.as_json
    end

    it 'allow teacher' do
      project.reload
      set_token teacher.token
      original = project.as_json
      put :update, format: :json, id: project.id, quiz: true
      expect(response).to be_success
      project.reload
      expect(original).to_not eql project.as_json
    end
  end
  describe "destroy" do
    let(:project) {FactoryGirl.create(:project, published: true, course: published_course)}
    it 'disallow unauthorized' do
      delete :destroy, format: :json, id: project.id
      expect(response).to be_unauthorized
      expect(Project.exists?(project.id)).to be true
    end

    it 'disallow student' do
      set_token student.token
      delete :destroy, format: :json, id: project.id
      expect(response).to be_forbidden
      expect(Project.exists?(project.id)).to be true
    end

    it 'allow teacher' do
      project
      expect {
        set_token teacher.token
        delete :destroy, format: :json, id: project.id
      }.to change(Project, :count).by -1
      expect(response).to be_success
      expect(Project.exists?(project.id)).to be false
    end
  end
end
