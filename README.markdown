[Demo for Indy.rb!](http://github.com/janxious/indyrb_archival_demo)

Gems required to run unit tests:

* redgreen
* assertions

_Foo has_many Bar_ - acts_as_paranoid test models
_Xx has_many Yy_ - acts_as_archival test models

Reasons to hate AAP
1. It has an inconsistent interface<br />
See tests in [foo_test.rb](http://github.com/janxious/indyrb_archival_demo/blob/master/test/unit/foo_test.rb)

2. It is not atomic.<br />
see tests in [foo_test.rb](http://github.com/janxious/indyrb_archival_demo/blob/master/test/unit/foo_test.rb)<br />
[aap - parnoid.rb](http://github.com/technoweenie/acts_as_paranoid/blob/master/lib/caboose/acts/paranoid.rb)

        def recover!
          self.deleted_at = nil
          save!
        end
         
        def recover_with_associations!(*associations)
          self.recover!
          associations.to_a.each do |assoc|
            self.send(assoc).find_with_deleted(:all).each do |a|
              a.recover! if a.class.paranoid?
            end
          end
        end

3. [Warner Hertzog](http://www.youtube.com/watch?v=FxKtZmQgxrI)

4. The code is really complicated<br />
[aap - paranoid_find_wrapper.rb](http://github.com/technoweenie/acts_as_paranoid/blob/master/lib/caboose/acts/paranoid_find_wrapper.rb)

5. Using the code is really complicated<br />
See my examples above

6. It fucks with find, destroy, and delete.

This will screw you, immediately, or when it's really important.

Additionally, everyone needs on your team needs to know how and why it's screwing with these methods, or they will screw everyone.

7. Annoying
        f = Foo.first
        f.destroy
        f.recover! #ERRRORRRRROR, Wesley
        Foo.find_with_deleted(:all).first.recover!
         
        Foo.all_with_deleted doesn't exist
        Foo.first_with_deleted doesn't exist
        etc.


Reasons to love AAA
1. It's consistent

2. It has a simple interface
See xx_test
4 class methods added, 3 instance methods added

3. Atomic
you won't unarchive associations unintentionally

4. Our documentation isn't "Read the code"
Srsly, check out that README

Reasons to hate AAA
1. The code is still pretty complicated
/lib/expected_behavior/acts_as_archival.rb
