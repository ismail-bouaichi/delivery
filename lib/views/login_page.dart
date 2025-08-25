
import 'package:flutter/material.dart';
import 'package:my_app/views/register_page.dart';
import 'package:my_app/views/widgets/input_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/controllers/authentication.dart';

import 'package:get/get.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

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
              Text('Login Page',
              style: GoogleFonts.poppins(fontSize: size*0.050),),
          
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
                await _authenticationController.login(email: _emailController.text.trim(), password: _passwordController.text.trim());
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
                    'Login',
                    style: GoogleFonts.poppins(fontSize: size*0.040),
                    );
                 }
               ),
                ),

              const SizedBox(height: 30,),
                 TextButton(
                  onPressed: (){
                  Get.to(()=> const RegisterPage());
                 },
                  child: Text('Create a New Account',
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

