
class Ability
    include CanCan::Ability
  
    def initialize(user)
      # Define abilities for the passed in user here. For example:
      #
      # The first argument to `can` is the action you are giving the user
      # permission to do.
      # If you pass :manage it will apply to every action. Other common actions
      # here are :read, :create, :update and :destroy.
      #
      # The second argument is the resource the user can perform the action on.
      # If you pass :all it will apply to every resource. Otherwise pass a Ruby
      # class of the resource.
      #
      # The third argument is an optional hash of conditions to further filter the
      # objects.
      # For example, here the user can only update published articles.
      #
      #   can :update, Article, :published => true
      #
      # See the wiki for details:
      # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
      
      # isnt manage the same as the CRUD next line, Yes
      #can [:read, :create, :update, :destroy], [Work, Publication, Publisher, Group]
      
      # might want to see rails cast on CanCan for examples
      user ||= User.new # guest user (not logged in)
      
      unless user.is_libstaff?
        can :read, :all
      else
        
        # make all staff superadmin
        if user.role? :superadmin
          can :manage, :all
        
        else
          
          # this role would be more suitable for outside editors
          if user.role? :admin
            # these work
            can :manage, Work 
            #cannot :create, Work
            cannot :destroy, Work
            can :manage, Person
            cannot :destroy, Person
            
            # this works too, but for an outside person, do we want batch uploading
            # would want to remove link to batch, and then only allow manual creation
            #can :manage, Import
            
            # these FAIL, specifically the [:read, :create etc]
            #can [:read, :create, :update], Work 
            #can [:read, :create, :update], [Work, Person]
          
          elsif user.role? :editor 
            # current_user is not available in class Ability
            #cuser = current_user.nil? ? false : current_user
            #if user == cuser
              #can [:read, :create, :update], [Work, Person] 
              # this doesn't work would need to set up a scope in Work and then use it here
              #can [:destroy] if cuser.roles.where(authorizable_type: Work).collect{|aid| aid.authorizable_id}.include?(some_work_id)
            #else
            #end
            
            can :read, :all
            
          else
            can :read, :all
          end
        end
      end         
    end
  end