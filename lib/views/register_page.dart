
import 'package:flutter/material.dart';
import 'package:my_app/controllers/authentication.dart';
import 'package:my_app/views/login_page.dart';
import 'package:my_app/views/widgets/input_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
    final TextEditingController _nameController=TextEditingController();
  final TextEditingController _usernameController=TextEditingController();
  final TextEditingController _emailController=TextEditingController();
  final TextEditingController _passwordController=TextEditingController();

  final AuthenticationController _authenticationController=Get.put(AuthenticationController());



  @override
  Widget build(BuildContext context) {
    var size=MediaQuery.of(context).size.width;
    return  Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal:20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              Text('Register Page',
              style: GoogleFonts.poppins(fontSize: size*0.050),),
          const SizedBox(
              height: 30,
            ),
            InputWidget(
              hintText:'Name',
              obscureText:false,
              controller:_nameController,
            ),const SizedBox(
              height: 30,
            ),
            InputWidget(
              hintText:'User Name',
              obscureText:false,
              controller:_usernameController,
            ),
             const SizedBox(
              height: 30,
            ),
            InputWidget(
              hintText:'Email',
              obscureText:false,
              controller:_emailController,
            ),
                  const SizedBox(
              height: 30,
            ),
             InputWidget(
              hintText:'Password',
              obscureText:true,
              controller:_passwordController,
             ),
             const SizedBox(
              height: 30,
            ),
         
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 50,vertical: 15)
                  ),
                  onPressed: ()async{
                    await _authenticationController.register(
                      name: _nameController.text.trim(),
                       email: _emailController.text.trim(),
                        username: _usernameController.text.trim(), 
                        password: _passwordController.text.trim());
                  },
                   child:  Obx(() {
                       return
                   _authenticationController.isLoading.value ?
                   const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                   ):
                       
                        Text(
                        'Register',
                        style: GoogleFonts.poppins(fontSize: size*0.040),
                        );
                     }
                   )
                    ),
                const SizedBox(height: 20,),
                TextButton(
                  onPressed: (){
                  Get.to(()=> const LoginPage());
                 },
                  child: Text('Already got Account',
                  style: GoogleFonts.poppins(
                    fontSize: size*0.040,
                     color:Colors.blue,
                    ),
                 
                  ))
                ],
          ),
        ),
        
  
      ),
    );
  }
}

